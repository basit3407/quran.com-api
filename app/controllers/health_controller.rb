# frozen_string_literal: true

class HealthController < ApplicationController
  # Lightweight liveness endpoint: confirms app process & middleware stack respond.
  def show
    render json: { status: 'ok' }
  end
end
