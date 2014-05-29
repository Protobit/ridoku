require 'test/unit'
require 'test_helper'

require 'ridoku/list'

class ListTest < Test::Unit::TestCase
  def setup
    init_ridoku(:default, :list)

    @list = Ridoku::List.new
  end

  def test_stacks_list_existing_stacks
    sub_command('stacks')

    AWS::OpsWorks.stack('test/configs/test_stack.json')

    out, err = capture_output do
      @list.run()
    end

    assert_not_equal nil, out.string.match(/Test-West/),
      'Should contain test stack.'
    assert_not_equal nil, out.string.match(/Test-East/),
      'Should contain test stack.'
    assert_equal 0, err.string.length, 'Should have no error text.'
  end
end