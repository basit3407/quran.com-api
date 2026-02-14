class UpdateSubTypeForLayeredTranslations < ActiveRecord::Migration[7.0]
  def up
    # Update existing layered translations from 'translation' to 'layered-translation'
    # This migration updates records that were previously identified by the metadata flag
    execute <<-SQL.squish
      UPDATE resource_contents
      SET sub_type = 'layered-translation'
      WHERE sub_type = 'translation'
        AND cardinality_type = '1_ayah'
        AND meta_data ->> 'is-layered-translation' = 'true'
    SQL
  end

  def down
    # Revert back to 'translation' sub_type
    execute <<-SQL.squish
      UPDATE resource_contents
      SET sub_type = 'translation'
      WHERE sub_type = 'layered-translation'
    SQL
  end
end
