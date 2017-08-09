defmodule EmqEsStorage.Server do
  use GenServer
  require Que

  @doc """
  Starts the registry.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Looks up the bucket pid for `name` stored in `server`.

  Returns `{:ok, pid}` if the bucket exists, `:error` otherwise.
  """
  def store_on_es(server, topic, payload) do
    GenServer.call(server, {:store_on_es, topic, payload})
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, %{}}
  end

  def get_index_chat do
    "/chat-#{Date.utc_today}"
  end

  def es_document(topic, payload) do
    {get_index_chat(),
     %{"topic" => topic,
      "payload" => payload,
      "timestamp" => DateTime.utc_now |> DateTime.to_iso8601
    }}
  end

  def handle_call({:store_on_es, topic, payload}, _from, state) do
    Que.add(EmqEsStorage.Elasticsearch, es_document(topic, payload))
    {:reply, :ok, state}
  end

end
