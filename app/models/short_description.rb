# frozen_string_literal: true

# == Schema Information
#
# Table name: short_descriptions
#
#  id                :integer          not null, primary key
#  description       :string(50)
#  language_name     :string
#  language_priority :integer
#  resource_type     :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  language_id       :integer
#  resource_id       :integer
#
# Indexes
#
#  index_short_descriptions_on_language_id                    (language_id)
#  index_short_descriptions_on_language_priority              (language_priority)
#  index_short_descriptions_on_resource_type_and_resource_id  (resource_type,resource_id)
#
class ShortDescription < ApplicationRecord
  include LanguageFilterable

  belongs_to :resource, polymorphic: true
end
