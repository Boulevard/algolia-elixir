defmodule Algolia.Config do
  @moduledoc """
  Configuration for algolia API client
  """

  alias Algolia.MissingAPIKeyError
  alias Algolia.MissingApplicationIDError

  @type t :: %__MODULE__{
          application_id: application_id,
          api_key: api_key,
          base_url_fn: base_url_fn
        }

  @type application_id :: String.t()
  @type api_key :: String.t()
  @type base_url_fn :: (:read | :write, application_id, retry :: integer -> String.t())

  @derive {Inspect, only: [:application_id]}

  defstruct [:application_id, :api_key, :base_url_fn]

  @type new_opt ::
          {:application_id, application_id} | {:api_key, String.t()} | {:base_url_fn, base_url_fn}

  @doc """
  Create a new config struct
  """
  @spec new([new_opt]) :: t
  def new(opts \\ []) when is_list(opts) do
    opts =
      opts
      |> Keyword.validate!([
        :application_id,
        :api_key,
        base_url_fn: &__MODULE__.default_base_url_fn/3
      ])
      |> Keyword.put_new_lazy(:application_id, &application_id_from_env!/0)
      |> Keyword.put_new_lazy(:api_key, &api_key_from_env!/0)

    struct!(__MODULE__, opts)
  end

  @spec application_id_from_env!() :: application_id | no_return()
  def application_id_from_env! do
    System.get_env("ALGOLIA_APPLICATION_ID") || Application.get_env(:algolia, :application_id) ||
      raise MissingApplicationIDError
  end

  @spec api_key_from_env!() :: api_key | no_return()
  def api_key_from_env! do
    System.get_env("ALGOLIA_API_KEY") || Application.get_env(:algolia, :api_key) ||
      raise MissingAPIKeyError
  end

  @doc false
  @spec default_base_url_fn(:read | :write, String.t(), non_neg_integer()) :: String.t()
  def default_base_url_fn(read_or_write, application_id, retry) do
    "https://" <> host(read_or_write, application_id, retry)
  end

  defp host(:read, application_id, 0), do: "#{application_id}-dsn.algolia.net"
  defp host(:write, application_id, 0), do: "#{application_id}.algolia.net"

  defp host(_read_or_write, application_id, curr_retry) when curr_retry <= 3,
    do: "#{application_id}-#{curr_retry}.algolianet.com"
end
