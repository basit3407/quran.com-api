# frozen_string_literal: true

class ReadinessController < ApplicationController
  # Readiness: returns 200 if all dependencies up, 503 if any down.
  def show
    checks = {}

    checks[:database] = dep_check('database') do
      ActiveRecord::Base.connection.execute('SELECT 1')
      'up'
    end

    checks[:redis] = dep_check('redis') do
      k = Kredis.string("readiness:#{Process.pid}")
      k.value = '1'
      k.value == '1' ? 'up' : 'down'
    end

    checks[:elasticsearch] = dep_check('elasticsearch') do
      client = Elasticsearch::Model.client
      resp = client.cluster.health(timeout: '1s')
      resp && resp['status'].present? ? 'up' : 'down'
    end

    overall_ok = checks.values.all? { |v| v == 'up' }
    status_code = overall_ok ? :ok : :service_unavailable
    render json: { status: overall_ok ? 'ok' : 'degraded', checks: checks }, status: status_code
  end

  private
  def dep_check(label)
    yield
  rescue => e
    Rails.logger.warn("readiness #{label} error: #{e.class}: #{e.message}")
    'down'
  end
end
