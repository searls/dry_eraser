ActiveRecord::Schema.define do
  create_table :whiteboards, force: true do |t|
    t.string :content
    t.boolean :someone_wrote_do_not_erase_on_me, default: false, null: false
  end

  create_table :classrooms, force: true do |t|
    t.references :whiteboard, foreign_key: true
  end
end

class Classroom < ActiveRecord::Base
  belongs_to :whiteboard, dependent: :destroy
end

class AnnoyingCoworkerMessageEraser
  def dry_erase(model)
    if model.someone_wrote_do_not_erase_on_me?
      model.errors.add(:someone_wrote_do_not_erase_on_me, "so I can't erase it")
    end
  end
end

class ForeignKeyEraser
  def initialize(foreign_model, foreign_key)
    @foreign_model = foreign_model
    @foreign_key = foreign_key
  end

  def dry_erase(model)
    if @foreign_model.where(@foreign_key => model).exists?
      model.errors.add(@foreign_key, "is still in use")
    end
  end
end

class Whiteboard < ActiveRecord::Base
  has_one :classroom

  dry_erase :must_have_content, AnnoyingCoworkerMessageEraser
  dry_erase ->(model) { model.content == "🖍️" && model.errors.add(:base, "No crayon, c'mon!") }
  dry_erase ForeignKeyEraser.new(Classroom, :whiteboard)

  private

  def must_have_content
    if content.blank?
      errors.add(:content, "must have content")
    end
  end
end
