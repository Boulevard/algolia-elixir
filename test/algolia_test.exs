defmodule AlgoliaTest do
  use ExUnit.Case

  import Algolia

  @indexes [
    "test",
    "multi_test_1",
    "multi_test_2",
    "delete_by_test_1",
    "move_index_test_src",
    "move_index_test_dst",
    "copy_index_src",
    "copy_index_dst",
    "search_index",
    "settings_test"
  ]

  setup_all do
    @indexes
    |> Enum.map(&clear_index/1)
    |> Enum.each(&wait/1)
  end

  test "add object" do
    {:ok, %{"objectID" => object_id}} =
      "test"
      |> add_object(%{text: "hello"})
      |> wait()

    assert {:ok, %{"text" => "hello"}} = get_object("test", object_id)
  end

  test "add multiple objects" do
    assert {:ok, %{"objectIDs" => ids}} =
             "test"
             |> add_objects([
               %{text: "add multiple test"},
               %{text: "add multiple test"},
               %{text: "add multiple test"}
             ])
             |> wait(3_000)

    for id <- ids do
      assert {:ok, %{"text" => "add multiple test"}} = get_object("test", id)
    end
  end

  test "list all indexes" do
    assert {:ok, %{"items" => _items}} = list_indexes()
  end

  test "wait task" do
    :rand.seed(:exs1024, :erlang.timestamp())
    object_id = 1_000_000 |> :rand.uniform() |> to_string()

    {:ok, %{"objectID" => ^object_id, "taskID" => task_id}} = save_object("test", %{}, object_id)

    wait_task("test", task_id)

    assert {:ok, %{"objectID" => ^object_id}} = get_object("test", object_id)
  end

  test "save one object, and then read it, using wait_task pipeing" do
    :rand.seed(:exs1024, :erlang.timestamp())
    id = 1_000_000 |> :rand.uniform() |> to_string()

    {:ok, %{"objectID" => object_id}} =
      "test"
      |> save_object(%{}, id)
      |> wait()

    assert object_id == id
    assert {:ok, %{"objectID" => ^object_id}} = get_object("test", id)
  end

  describe "save_object/2" do
    test "requires an objectID attribute" do
      assert_raise ArgumentError, ~r/must have an objectID/, fn ->
        save_object("test", %{"noObjectId" => "raises error"})
      end
    end

    test "requires a valid attribute as object id" do
      assert_raise ArgumentError, ~r/does not have a 'id' attribute/, fn ->
        save_object("test", %{"noId" => "raises error"}, id_attribute: "id")
      end
    end
  end

  test "search single index" do
    :rand.seed(:exs1024, :erlang.timestamp())
    count = :rand.uniform(10)
    docs = Enum.map(1..count, &%{id: &1, test: "search_single_index"})

    {:ok, _} = "test" |> save_objects(docs, id_attribute: :id) |> wait()

    {:ok, %{"hits" => hits1}} = search("test", "search_single_index")
    assert length(hits1) === count
  end

  test "search with list opts" do
    :rand.seed(:exs1024, :erlang.timestamp())
    count = :rand.uniform(10)
    docs = Enum.map(1..count, &%{id: &1, test: "search with list opts"})

    {:ok, _} = "test" |> save_objects(docs, id_attribute: :id) |> wait()

    opts = [
      responseFields: ["hits", "nbPages"]
    ]

    {:ok, response} = search("test", "search_with_list_opts", opts)

    assert response["hits"]
    assert response["nbPages"]
    refute response["page"]
  end

  test "search > 1 pages" do
    docs = Enum.map(1..40, &%{id: &1, test: "search_more_than_one_pages"})

    {:ok, _} = "test" |> save_objects(docs, id_attribute: :id) |> wait()

    {:ok, %{"hits" => hits, "page" => page}} =
      search("test", "search_more_than_one_pages", page: 1)

    assert page == 1
    assert length(hits) === 20
  end

  test "search multiple indexes" do
    :rand.seed(:exs1024, :erlang.timestamp())

    indexes = ["multi_test_1", "multi_test_2"]

    fixture_list = Enum.map(indexes, &generate_fixtures_for_index/1)

    {:ok, %{"results" => results}} =
      indexes
      |> Enum.map(&%{index_name: &1, query: "search_multiple_indexes"})
      |> multi()

    for {index, count} <- fixture_list do
      hits =
        results
        |> Enum.find(fn result -> result["index"] == index end)
        |> Map.fetch!("hits")

      assert length(hits) == count
    end
  end

  test "search for facet values" do
    {:ok, _} =
      "test"
      |> set_settings(%{attributesForFaceting: ["searchable(family)"]})
      |> wait()

    docs = [
      %{family: "Diplaziopsidaceae", name: "D. cavaleriana"},
      %{family: "Diplaziopsidaceae", name: "H. marginatum"},
      %{family: "Dipteridaceae", name: "D. nieuwenhuisii"}
    ]

    {:ok, _} = "test" |> add_objects(docs) |> wait()

    {:ok, %{"facetHits" => hits}} = search_for_facet_values("test", "family", "Dip")

    assert [
             %{
               "count" => 2,
               "highlighted" => "<em>Dip</em>laziopsidaceae",
               "value" => "Diplaziopsidaceae"
             },
             %{
               "count" => 1,
               "highlighted" => "<em>Dip</em>teridaceae",
               "value" => "Dipteridaceae"
             }
           ] == hits
  end

  defp generate_fixtures_for_index(index) do
    :rand.seed(:exs1024, :erlang.timestamp())
    count = :rand.uniform(3)
    objects = Enum.map(1..count, &%{objectID: &1, test: "search_multiple_indexes"})
    index |> save_objects(objects) |> wait(3_000)
    {index, length(objects)}
  end

  test "search query with special characters" do
    {:ok, %{"hits" => _}} = "test" |> search("foo & bar") |> wait()
  end

  test "partially update object" do
    {:ok, %{"objectID" => object_id}} =
      "test"
      |> save_object(%{id: "partially_update_object"}, id_attribute: :id)
      |> wait()

    assert {:ok, _} = "test" |> partial_update_object(%{update: "updated"}, object_id) |> wait()

    {:ok, object} = get_object("test", object_id)
    assert object["update"] == "updated"
  end

  test "partially update object, upsert true" do
    id = "partially_update_object_upsert_true"

    assert {:ok, _} =
             "test"
             |> partial_update_object(%{}, id)
             |> wait()

    {:ok, object} = get_object("test", id)
    assert object["objectID"] == id
  end

  test "partial update object, upsert is false" do
    id = "partial_update_upsert_false"

    assert {:ok, _} =
             "test"
             |> partial_update_object(%{update: "updated"}, id, upsert?: false)
             |> wait()

    assert {:error, 404, _} = get_object("test", id)
  end

  test "partially update multiple objects, upsert is default" do
    objects = [%{id: "partial_update_multiple_1"}, %{id: "partial_update_multiple_2"}]

    assert {:ok, _} =
             "test"
             |> partial_update_objects(objects, id_attribute: :id)
             |> wait()

    assert {:ok, _} = get_object("test", "partial_update_multiple_1")
    assert {:ok, _} = get_object("test", "partial_update_multiple_2")
  end

  test "partially update multiple objects, upsert is false" do
    objects = [
      %{id: "partial_update_multiple_1_no_upsert"},
      %{id: "partial_update_multiple_2_no_upsert"}
    ]

    assert {:ok, _} =
             "test"
             |> partial_update_objects(objects, id_attribute: :id, upsert?: false)
             |> wait()

    assert {:error, 404, _} = get_object("test", "partial_update_multiple_1_no_upsert")
    assert {:error, 404, _} = get_object("test", "partial_update_multiple_2_no_upsert")
  end

  test "delete object" do
    {:ok, %{"objectID" => object_id}} =
      "test"
      |> save_object(%{id: "delete_object"}, id_attribute: :id)
      |> wait()

    "test" |> delete_object(object_id) |> wait()

    assert {:error, 404, _} = get_object("test", object_id)
  end

  test "deleting an object with empty string should return an error" do
    assert {:error, %Algolia.InvalidObjectIDError{}} = delete_object("test", "")
  end

  test "delete multiple objects" do
    objects = [%{id: "delete_multipel_objects_1"}, %{id: "delete_multipel_objects_2"}]

    {:ok, %{"objectIDs" => object_ids}} =
      "test"
      |> save_objects(objects, id_attribute: :id)
      |> wait()

    "test" |> delete_objects(object_ids) |> wait()

    assert {:error, 404, _} = get_object("test", "delete_multipel_objects_1")
    assert {:error, 404, _} = get_object("test", "delete_multipel_objects_2")
  end

  describe "delete_by/2" do
    test "deletes according to filters" do
      {:ok, _} =
        "delete_by_test_1"
        |> set_settings(%{attributesForFaceting: ["filterOnly(score)"]})
        |> wait()

      objects = [%{id: "gets deleted", score: 10}, %{id: "remains there", score: 20}]

      {:ok, _} =
        "delete_by_test_1"
        |> save_objects(objects, id_attribute: :id)
        |> wait()

      results =
        "delete_by_test_1"
        |> delete_by(filters: "score < 15")
        |> wait()

      assert {:ok, _} = results

      assert {:error, 404, _} = get_object("delete_by_test_1", "gets deleted")
      assert {:ok, _} = get_object("delete_by_test_1", "remains there")
    end

    test "requires opts" do
      assert_raise ArgumentError, ~r/opts are required/, fn ->
        delete_by("delete_by_test_1", [])
      end
    end

    test "ignores hitsPerPage and attributesToRetrieve opts" do
      assert_raise ArgumentError, ~r/opts are required/, fn ->
        delete_by("delete_by_test_1", hitsPerPage: 10, attributesToRetrieve: [])
      end
    end
  end

  test "settings" do
    attributesToIndex = ~w(foo bar baz)

    assert {:ok, _} =
             "settings_test"
             |> set_settings(%{attributesToIndex: attributesToIndex})
             |> wait()

    assert {:ok, %{"attributesToIndex" => ^attributesToIndex}} = get_settings("settings_test")
  end

  test "move index" do
    src = "move_index_test_src"
    dst = "move_index_test_dst"

    objects = [%{id: "move_1"}, %{id: "move_2"}]

    {:ok, _} = src |> save_objects(objects, id_attribute: :id) |> wait()
    {:ok, _} = src |> move_index(dst) |> wait()

    assert {:ok, %{"objectID" => "move_1"}} = get_object(dst, "move_1")
    assert {:ok, %{"objectID" => "move_2"}} = get_object(dst, "move_2")
  end

  test "copy index" do
    src = "copy_index_src"
    dst = "copy_index_dst"

    objects = [%{id: "copy_1"}, %{id: "copy_2"}]

    {:ok, _} = src |> save_objects(objects, id_attribute: :id) |> wait()
    {:ok, _} = src |> copy_index(dst) |> wait()

    assert {:ok, %{"objectID" => "copy_1"}} = get_object(dst, "copy_1")
    assert {:ok, %{"objectID" => "copy_2"}} = get_object(dst, "copy_2")
  end

  test "deletes an index" do
    index = "delete_test_index"
    index |> add_object(%{objectID: "delete_test"}) |> wait()

    {:ok, %{"items" => items}} = list_indexes()
    all_indexes = Enum.map(items, & &1["name"])
    assert index in all_indexes

    assert {:ok, _} = index |> delete_index() |> wait()
    {:ok, %{"items" => items}} = list_indexes()
    all_indexes = Enum.map(items, & &1["name"])
    refute index in all_indexes
  end

  test "get index logs" do
    {:ok, _} =
      "search_index"
      |> add_object(%{text: "hello"})
      |> wait()

    {:ok, _} = "search_index" |> search("test query") |> wait()

    assert {:ok, %{"logs" => [log]}} =
             get_logs(indexName: "search_index", length: 1, type: :query)

    assert %{"index" => "search_index", "query_params" => "query=test+query"} = log
  end

  test "forwards extra HTTP headers" do
    opts = [headers: [{"X-Forwarded-For", "1.2.3.4"}]]

    {:ok, _} =
      "search_index"
      |> add_object(%{text: "hello"}, request_options: opts)
      |> wait()

    {:ok, %{"logs" => [log]}} = get_logs(indexName: "search_index", length: 1, type: :build)
    %{"index" => "search_index", "query_headers" => headers} = log
    assert headers =~ ~r/X-Forwarded-For: 1\.2\.3\.4/
  end
end
