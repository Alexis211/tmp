defmodule NothingTest do
  use ExUnit.Case
  doctest Nothing

  test "greets the world" do
    assert Nothing.hello() == :world
  end
end
