require 'faraday'
require 'singleton'

class SunnahApi
  include Singleton

  DEFAULT_LANGUAGE = 'en'.freeze
  API_KEY_ENV = 'SUNNAH_API_KEY'.freeze
  API_URL_ENV = 'SUNNAH_API_URL'.freeze
  DEFAULT_COLLECTIONS_LIMIT = 100

  def initialize
    @collections_by_name = {}
  end

  def hadith_by_urns(urns, language: DEFAULT_LANGUAGE)
    raw_response = hadith_by_urns_raw(urns)
    return raw_response unless raw_response.is_a?(Hash)
    return raw_response unless raw_response['data'].is_a?(Array)

    language_code = language.to_s.downcase == 'ar' ? 'ar' : 'en'

    data = raw_response['data'].map do |item|
      flatten_hadith_item(item, language: language_code)
    end

    raw_response.merge('data' => data)
  end

  def hadith_by_urns_raw(urns)
    urn_list = normalize_urns(urns)
    return error_response(400, 'urns is required') if urn_list.empty?

    send_request('hadiths/urns', urns: urn_list.join(','))
  end

  def get_collection(name)
    return nil if name.to_s.strip.empty?

    get_collections
    @collections_by_name[name.to_s.strip]
  end

  def collections
    get_collections
    @collections_by_name.values
  end

  private

  def get_collections
    return @collections_by_name unless @collections_by_name.empty?

    _fetch_collections
  end

  def _fetch_collections
    response = send_request('collections', limit: DEFAULT_COLLECTIONS_LIMIT, page: 1)
    return unless response.is_a?(Hash) && response['data'].is_a?(Array)

    response['data'].each do |item|
      next unless item.is_a?(Hash)

      item_name = item['name'].to_s
      next if item_name.empty?

      @collections_by_name[item_name] = item
    end

    @collections_by_name
  end

  def normalize_urns(urns)
    Array(urns).flatten.compact.map(&:to_s).map(&:strip).reject(&:empty?)
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

  def flatten_hadith_item(item, language: DEFAULT_LANGUAGE)
    return item unless item.is_a?(Hash)

    flattened = item.dup
    hadiths = flattened.delete('hadith') || []
    all_grades = []

    hadiths.each do |hadith|
      next unless hadith.is_a?(Hash)

      lang = hadith['lang'].to_s

      is_language_arabic = language == 'ar'

      # For body/urn: extract all languages unless language is Arabic
      if (is_language_arabic && lang == "ar") || !is_language_arabic
        flattened["#{lang}_body"] = hadith['body'] if hadith.key?('body')
        flattened["#{lang}_urn"] = hadith['urn'] if hadith.key?('urn')
      end

      # For grades: same filter but exclude Arabic when language is not Arabic
      include_grade = (is_language_arabic && lang == "ar") || !is_language_arabic && lang != "ar"

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

    # Add collection name
    collection_name = flattened['collection']
    if collection_name
      collection = get_collection(collection_name)
      if collection
        collection_info = collection['collection']&.find { |c| c['lang'] == language }
        title = collection_info&.dig('title')
        flattened['name'] = title if title
      end
    end

    flattened
  end
end
