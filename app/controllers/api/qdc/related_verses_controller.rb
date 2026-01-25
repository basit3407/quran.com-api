# frozen_string_literal: true

module Api::Qdc
  class RelatedVersesController < ApiController
    before_action :init_presenter

    def by_key
      render
    end

    private

    def init_presenter
      @presenter = Qdc::RelatedVersesPresenter.new(params, action_name)
    end
  end
end

