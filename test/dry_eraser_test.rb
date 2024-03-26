class TestDryEraser < TLDR
  def setup
    @subject = Whiteboard.new
    super
  end

  def test_dry_erase_succeeding
    @subject.content = "Hello, world!"

    assert @subject.destroy
    assert_empty @subject.errors
  end

  def test_dry_erase_failing
    refute @subject.destroy
    assert_equal({content: ["must have content"]}, @subject.errors.messages)
  end

  def test_dry_erasable_succeeding
    @subject.content = "Stuff"

    assert @subject.dry_erasable?
    assert_empty @subject.errors
  end

  def test_dry_erasable_failing
    refute @subject.dry_erasable?
    assert_equal({content: ["must have content"]}, @subject.errors.messages)
  end

  def test_dry_erasing_association
    classroom = Classroom.new(whiteboard: @subject)

    refute classroom.destroy
    assert_equal({content: ["must have content"]}, classroom.whiteboard.errors.messages)
  end

  def test_dry_erasing_as_class
    @subject.content = "lol"
    @subject.someone_wrote_do_not_erase_on_me = true

    refute @subject.dry_erasable?
    assert_equal(["Someone wrote do not erase on me so I can't erase it"], @subject.errors.full_messages)
  end

  def test_dry_erasing_as_instance
    @subject.content = "lol"
    Classroom.create!(whiteboard: @subject)

    refute @subject.destroy
    assert_equal(["Whiteboard is still in use"], @subject.errors.full_messages)
  end

  def test_dry_erasing_as_callable
    @subject.content = "🖍️"

    refute @subject.destroy
    assert_equal(["No crayon, c'mon!"], @subject.errors.full_messages)
  end

  def test_that_it_has_a_version_number
    refute_nil ::DryEraser::VERSION
  end
end
