defmodule HelloDocumentsSpeakingTest do
  use ExUnit.Case
  doctest HelloDocumentsSpeaking

  test "greets the world" do
    assert HelloDocumentsSpeaking.hello() == :world
  end
end
