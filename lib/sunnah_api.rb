require 'faraday'
require 'singleton'

class SunnahApi
  include Singleton

  DEFAULT_LANGUAGE = 'en'.freeze
  API_KEY_ENV = 'SUNNAH_API_KEY'.freeze
  API_URL_ENV = 'SUNNAH_API_URL'.freeze
  DEFAULT_COLLECTIONS_LIMIT = 100

  def initialize
    @collections_mutex = Mutex.new
    @collections_cv = ConditionVariable.new
    reset_collections_cache!
  end

  def hadith_by_urns(urns, language: DEFAULT_LANGUAGE)
    raw_response = hadith_by_urns_raw(urns)
    return raw_response unless raw_response.is_a?(Hash)
    return raw_response unless raw_response['data'].is_a?(Array)

    only_language = language.to_s.downcase == 'ar' ? 'ar' : nil
    language_code = language.to_s.downcase == 'ar' ? 'ar' : 'en'

    data = raw_response['data'].map do |item|
      flattened = flatten_hadith_item(item, only_language: only_language)
      add_collection_name_to_hadith(flattened, language_code)
    end

    raw_response.merge('data' => data)
  end

  def hadith_by_urns_raw(urns)
    urn_list = normalize_urns(urns)
    return error_response(400, 'urns is required') if urn_list.empty?

    send_request('hadiths/urns', urns: urn_list.join(','))
  end

  def get_collection(name)
    collection_name = name.to_s.strip
    return nil if collection_name.empty?

    ensure_collections_loaded_for!(collection_name)
    @collections_mutex.synchronize { @collections_by_name[collection_name] }
  end

  def collections
    ensure_collections_loaded_for!(nil)
    @collections_mutex.synchronize { @collections_by_name.values }
  end

  private

  def normalize_urns(urns)
    Array(urns).flatten.compact.map(&:to_s).map(&:strip).reject(&:empty?)
  end

  def ensure_collections_loaded_for!(collection_name)
    @collections_mutex.synchronize do
      return if @collections_status == :loaded
      return if collection_name && @collections_by_name.key?(collection_name)

      if @collections_status == :pending
        while @collections_status == :pending
          @collections_cv.wait(@collections_mutex)
        end

        return if @collections_status == :loaded
        return if collection_name && @collections_by_name.key?(collection_name)
      end

      @collections_status = :pending
    end

    begin
      fetch_all_collections_into_cache!
      @collections_mutex.synchronize do
        @collections_status = :loaded
        @collections_last_error = nil
        @collections_cv.broadcast
      end
    rescue StandardError => e
      @collections_mutex.synchronize do
        @collections_status = :idle
        @collections_last_error = e
        @collections_cv.broadcast
      end
    end
  end

  def fetch_all_collections_into_cache!
    loop do
      limit = nil
      page = nil
      @collections_mutex.synchronize do
        limit = @collections_limit
        page = @collections_next_page
      end

      break if page.nil?

      response = fetch_collections_page_raw(limit: limit, page: page)
      unless response.is_a?(Hash) && response['data'].is_a?(Array)
        raise "Unexpected collections response for page=#{page}: #{response.inspect}"
      end

      @collections_mutex.synchronize do
        response['data'].each do |item|
          next unless item.is_a?(Hash)

          item_name = item['name'].to_s
          next if item_name.empty?

          @collections_by_name[item_name] ||= item
        end

        next_page = normalize_page_number(response['next'])
        @collections_next_page = next_page
        @collections_total = response['total'] if response.key?('total')
        @collections_last_successful_page = page
      end
    end
  end

  def fetch_collections_page_raw(limit:, page:)
    capped_limit = [limit.to_i, 1].max
    capped_limit = [capped_limit, DEFAULT_COLLECTIONS_LIMIT].min
    page_number = [page.to_i, 1].max

    send_request('collections', limit: capped_limit, page: page_number)
  end


  def normalize_page_number(value)
    return nil if value.nil?

    num = value.to_i
    num.positive? ? num : nil
  end

  def reset_collections_cache!
    @collections_status = :idle
    @collections_last_error = nil
    @collections_by_name = {}
    @collections_total = nil
    @collections_limit = DEFAULT_COLLECTIONS_LIMIT
    @collections_next_page = 1
    @collections_last_successful_page = 0
  end

  def send_request(path, params)
    headers = {
      'X-API-Key' => sunnah_api_key,
      'Accept' => 'application/json'
    }

    process_response Faraday.get("#{sunnah_base_url}/#{path}", params, headers)
  end

  def process_response(response)
    return Oj.load(response.body) if response.status == 200

    error_response(response.status, api_error_message(response.status))
  end

  def api_error_message(code)
    case code.to_i
    when 400
      'Bad Request.'
    when 401
      'Unauthorized.'
    when 403
      'Forbidden.'
    when 404
      'Not Found.'
    when 429
      'Too Many Requests.'
    when 500
      'Internal Server Error.'
    else
      'Request failed.'
    end
  end

  def error_response(status, message)
    { 'status' => status.to_i, 'message' => message.to_s }
  end

  def sunnah_api_key
    raw = ENV.fetch(API_KEY_ENV, nil).to_s.strip
    raise ArgumentError, "#{API_KEY_ENV} is required" if raw.empty?

    raw
  end

  def sunnah_base_url
    raw = ENV.fetch(API_URL_ENV, nil).to_s.strip
    raise ArgumentError, "#{API_URL_ENV} is required" if raw.empty?

    raw.sub(%r{/*\z}, '')
  end

  def add_collection_name_to_hadith(hadith, language)
    return hadith unless hadith.is_a?(Hash)

    collection_name = hadith['collection']
    return hadith unless collection_name

    collection = get_collection(collection_name)
    return hadith unless collection

    # Find the appropriate title based on language
    collection_info = collection['collection']&.find { |c| c['lang'] == language }
    title = collection_info&.dig('title')

    return hadith unless title

    hadith.merge('name' => title)
  end

  def flatten_hadith_item(item, only_language: nil)
    return item unless item.is_a?(Hash)

    flattened = item.dup
    hadiths = flattened.delete('hadith') || []
    all_grades = []

    hadiths.each do |hadith|
      next unless hadith.is_a?(Hash)

      lang = hadith['lang'].to_s

      # For body/urn: extract all languages unless only_language is specified
      if only_language.nil? || lang == only_language
        flattened["#{lang}_body"] = hadith['body'] if hadith.key?('body')
        flattened["#{lang}_urn"] = hadith['urn'] if hadith.key?('urn')
      end

      # For grades: same filter but exclude Arabic when only_language is nil
      include_grade = (only_language.nil? && lang != 'ar') || (only_language && lang == only_language)

      if include_grade
        grades = hadith['grades'] || []
        grades.each do |grade|
          next unless grade.is_a?(Hash)
          next unless grade['grade']

          all_grades << {
            'grade' => grade['grade'],
            'gradeBy' => grade['graded_by']
          }
        end
      end
    end

    # Deduplicate grades
    grade_objects = all_grades.uniq
    flattened['grades'] = grade_objects unless grade_objects.empty?

    flattened
  end
end
