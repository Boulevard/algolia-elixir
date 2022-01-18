defmodule Algolia.ConfigTest do
  use ExUnit.Case, async: true

  alias Algolia.Config

  describe "new/1" do
    test "allows values to be overridden" do
      base_url_fn = fn _, _, _ -> :ok end
      config = Config.new(application_id: "foo", api_key: "secret", base_url_fn: base_url_fn)

      assert config.application_id == "foo"
      assert config.api_key == "secret"
      assert config.base_url_fn == base_url_fn
    end

    test "raises an ArgumentError on an invalid option" do
      assert_raise ArgumentError, fn ->
        Config.new(base_url: "hello")
      end
    end
  end

  test "inspect does not show the API key" do
    config = Config.new(application_id: "foo", api_key: "secret")

    refute inspect(config) =~ "secret"
  end
end
