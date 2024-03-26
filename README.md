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
