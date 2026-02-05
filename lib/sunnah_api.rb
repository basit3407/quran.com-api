require 'faraday'
require 'singleton'

class SunnahApi
  include Singleton

  DEFAULT_LANGUAGE = 'en'.freeze
  API_KEY_ENV = 'SUNNAH_API_KEY'.freeze
  API_URL_ENV = 'SUNNAH_API_URL'.freeze

  def hadith_by_urns(urns, language: DEFAULT_LANGUAGE)
    raw_response = hadith_by_urns_raw(urns)
    return raw_response unless raw_response.is_a?(Hash)
    return raw_response unless raw_response['data'].is_a?(Array)

    only_language = language.to_s.downcase == 'ar' ? 'ar' : nil
    raw_response.merge('data' => raw_response['data'].map { |item| flatten_hadith_item(item, only_language: only_language) })
  end

  def hadith_by_urns_raw(urns)
    urn_list = normalize_urns(urns)
    return error_response(400, 'urns is required') if urn_list.empty?

    send_request('hadiths/urns', urns: urn_list.join(','))
  end

  private

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

  def flatten_hadith_item(item, only_language: nil)
    return item unless item.is_a?(Hash)

    flattened = item.dup
    hadiths = flattened.delete('hadith') || []

    hadiths.each do |hadith|
      next unless hadith.is_a?(Hash)

      lang = hadith['lang'].to_s
      next if only_language && lang != only_language

      # Only extract specific fields: body, urn
      flattened["#{lang}_body"] = hadith['body'] if hadith.key?('body')
      flattened["#{lang}_urn"] = hadith['urn'] if hadith.key?('urn')
    end

    # Combine grades from all hadith objects into array of objects
    all_grades = hadiths.flat_map { |h| (h['grades'] || []).compact }

    # Filter grades by language if specified
    filtered_grades = only_language ? all_grades.select { |g| g['lang'] == only_language } : all_grades

    # Create array of unique grade objects (handle null graded_by)
    grade_objects = filtered_grades.map { |g|
      { 'grade' => g['grade'], 'gradeBy' => g['graded_by'] } if g['grade']
    }.compact.uniq

    flattened['grades'] = grade_objects unless grade_objects.empty?

    flattened
  end
end
