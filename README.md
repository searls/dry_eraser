# dry_eraser – a _dry_ run before you _erase_ your models

![dry_eraser](https://github.com/searls/dry_eraser/assets/79303/5dd8375e-c513-4f27-a90c-d74a2acaa62e)

This gem is for people who think it's weird that Rails offers so many ways to
validate models before you create and update them, but all it gives you is a
`before_destroy` hook before you permanently destroy them.

Think of `dry_eraser` as adding a validation feature to `ActiveRecord#destroy`.
To that end, it defines `dry_erase` and `dry_erasable?` methods for your models,
which behave analogously to `validates` and `valid?`, respectively. This way,
you won't need to register a `before_destroy` callback and then remember that
`throw(:abort)` is the magical incantation needed to cancel the callback chain.
If you're suspicious of pulling in a dependency for something like this (and you
should be), the fact its [implementation is 50 lines soaking
wet](lib/dry_eraser.rb) will hopefully put you at ease.

Here's how to use it.

## Install

Add it to your Gemfile:

```ruby
gem "dry_eraser"
```

Then run `bundle install`. That's it. Rails should load it automatically.

## Usage

Whenever there's a situation in which you know you _don't_ want to `destroy` a
model, you can specify it by calling the `dry_erase` class method in the model's
class.

Let's take an example `Whiteboard` model. Suppose it has a boolean attribute
called `someone_wrote_do_not_erase_on_me` and you want to be sure `destroy`
operations are aborted when that attribute is `true`.

You could:

```ruby
class Whiteboard < ActiveRecord::Base
  dry_erase :no_one_said_not_to_erase_it

  private

  def no_one_said_not_to_erase_it
    if someone_wrote_do_not_erase_on_me?
      errors.add(:someone_wrote_do_not_erase_on_me, "so I can't erase it")
    end
  end
end
```

This way, whenever `someone_wrote_do_not_erase_on_me?` is true, `destroy` will
return `false` (just like `save` returns false when validations fail).

This, combined with the fact that `dry_erase` determines success based on the
absence or presence of `errors` on the model instance will allow you to write
code that branches on whether destroy succeeded, just like you would for `save`
or `update`:

```ruby
whiteboard = Whiteboard.create!(someone_wrote_do_not_erase_on_me: true)
if whiteboard.destroy
  flash[:notice] = "Whiteboard deleted!"
  redirect_to whiteboards_path
else
  flash[:error] = whiteboard.errors.full_messages
  render :show, status: :unprocessable_entity
end
```

Want know whether a model is can be safely destroyed before you `destroy` it?
You can also call `dry_erasable?` and it'll either return `true` or return
`false` (and populate the `errors` object all the same):

```ruby
whiteboard = Whiteboard.create!(someone_wrote_do_not_erase_on_me: true)
whiteboard.dry_erasable?
=> false
whiteboard.errors.full_messages.first
=> "Someone wrote do not erase on me so I can't erase it"
```

Important consequence of this design: since `dry_eraser` mutates the same
`errors` object as built-in validations do, calling `dry_erasable?` or `destroy`
will _clear_ the model's `errors` object first.

## Other stuff you can pass to `dry_erase`

The `dry_erase` method can take one or more of any of the following:

* A symbol or string name of an instance method on the model
* A class that has a no-arg constructor and a `dry_erase(model)` method
* An object that responds to a `dry_erase(model)`
* An object (e.g. a proc or lambda) that responds to `call(model)`

You can see all of these uses in the gem's [test fixture](test/fixtures.rb):

```ruby
# You can specify multiple dry erasers at a time
dry_erase :must_have_content, AnnoyingCoworkerMessageEraser

# Or pass a lambda
dry_erase ->(model) { model.content == "🖍️" && model.errors.add(:base, "No crayon, c'mon!") }

# Or an instance of a class (which allows it to receive static configuration in an initializer)
dry_erase ForeignKeyEraser.new(Classroom, :whiteboard)
```

And that's about it.

## A real-world example

I'm currently developing an app for [my wife Becky's
business](http://www.betterwithbecky.com) and I'm modeling various
strength-training concepts. One model, `Movement`, depends on one or two pieces
of `Equipment`. Becky should be able to delete equipment records, but only if they
aren't currently assigned to any movements.

As you might guess, this concern is enforced in the database with a foreign key,
which was configured in the migration that defines the `movements` table.
Imagine something like this:

```ruby
create_table :movements do |t|
  t.string :name, null: false

  t.references :primary_equipment, foreign_key: {to_table: :equipments}, null: true
  t.references :secondary_equipment, foreign_key: {to_table: :equipments}, null: true

  t.timestamps
  t.unique_constraint :name
  end
end
```

Because `destroy` doesn't provide an easy way to run pre-flight validations, I
found myself writing a controller action like this on `EquipmentsController`:

```ruby
def destroy
  Equipment.find(params[:id]).destroy!
  flash[:notice] = "Equipment deleted!"
  redirect_to admin_equipments_path
end
```

Using a foreign key constraint and `destroy!` like this will indeed "work"
insofar as it will prevent `Movement` records from holding orphaned `Equipment`
references, but instead of seeing a pleasant error message generated at the
application layer, the user (/my spouse) will either see some gobbledygook
generated by Postgres or, worse, a generic 500 page.

Let's use `dry_eraser` to make this nicer!

All we need to do is define a dry eraser on the Equipment model to prevent its
deletion when it's still associated with any movements.

Since an `Equipment` can either fill a primary or secondary role in a `Movement`,
there are two foreign keys to consider as we use `dry_erase` to add what amounts
to a pretty normal-looking validation method:

```ruby
class Equipment < ApplicationRecord
  has_many :primary_movements, class_name: "Movement", foreign_key: "primary_equipment_id"
  has_many :secondary_movements, class_name: "Movement", foreign_key: "secondary_equipment_id"

  validates :name, presence: true, uniqueness: true

  dry_erase :no_associated_movements

  private

  def no_associated_movements
    if primary_movements.exists? || secondary_movements.exists?
      errors.add(:base, "Cannot destroy equipment because associated movements exist.")
    end
  end
end
```

Okay, now that we know destroy will abort when the operation is unsupported, we
can change our `destroy!` to `destroy` and wrap it in an `if`/`else` that will
more gracefully handle the situation in the user interface:

```ruby
def destroy
  @equipment = Equipment.find(params[:id])
  if @equipment.destroy
    flash[:notice] = "Equipment deleted!"
    redirect_to admin_equipments_path
  else
    flash[:error] = @equipment.errors.full_messages
    render :edit, status: :unprocessable_entity
  end
end
```

Squint and it looks like a `create` or `update` action.

To test that this is all working, we can throw up a link and see what happens
when we try to delete an `Equipment` that's associated with a `Movement`:

```erb
<%= link_to "Delete equipment",  admin_equipment_path(@equipment),
  data: {
    turbo_method: :delete,
    turbo_confirm: "Are you sure you want to delete this equipment?"
  }
%>
```

(The hardest part here is remembering that Rails 7 changed `data-confirm` to
`data-turbo-confirm`.)

Anyway, click that link, then click OK on the confirm dialog and… 🥁 drumroll 🥁…

![A flash message explaining the deletion attempt was
invalid.](https://github.com/searls/dry_eraser/assets/79303/1ace01c6-2524-40e5-9f69-65542a9dc7f0)

Yahtzee! We did it! See, that wasn't so bad.

## Extra credit assignment

To see a different way of accomplishing the same thing, we could also have
created a class that took configuration values in an initializer and then handled
each `destroy` attempt by implementing a `dry_erase(model)` method. Let's
refactor our approach to do that instead:

```ruby
dry_erase ForeignKeyEraser.new(association: :primary_movements)
dry_erase ForeignKeyEraser.new(association: :secondary_movements)
```

And then we can implement that class anywhere we like:

```ruby
class ForeignKeyEraser
  def initialize(association:)
    @association_name = association
  end

  def dry_erase(model)
    if model.association(@association_name).scope.exists?
      model.errors.add(:base, "Cannot destroy #{model.model_name.human} because associated #{@association_name.to_s.humanize} exist.")
    end
  end
end
```

The above reflects on the provided association name to look for existing records,
but we could have just as well taken a model and column name. Hopefully, this
gives you the general idea.

Now, let's make sure this works by trying to delete the equipment again:

![Cannot destroy Equipment because associated Primary movements exist.](https://github.com/searls/dry_eraser/assets/79303/de691f8b-e82a-4db6-9c57-f62639b6936e)

Even better!

Okay, job's done. Happy erasing!

## License

This is an [MIT](/LICENSE.txt) joint.
