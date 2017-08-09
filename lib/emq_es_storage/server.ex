defmodule EmqEsStorage.Server do
  use GenServer

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

  def sync_flush(server) do
    GenServer.call(server, {:sync_flush})
  end

  ## Server Callbacks

  def init(:ok) do
    schedule_flush()
    {:ok, %{buffer: []}}
  end

  def get_index_chat do
    "/chat-#{Date.utc_today}"
  end

  def es_document(topic, payload) do
    %{"topic" => topic,
      "payload" => payload,
      "timestamp" => DateTime.utc_now |> DateTime.to_iso8601
    }
  end

  def handle_call({:store_on_es, topic, payload}, _from, state) do
    new_state = %{buffer: state.buffer ++ [es_document(topic, payload)]}
    {:reply, :ok, new_state}
  end

  def handle_call({:sync_flush}, _from, state) do
    EmqEsStorage.Elasticsearch.index(
      "#{get_index_chat()}/message",
      state.buffer
    )
    {:reply, :ok, %{buffer: []}}
  end

  def handle_call({:cleanup_state}, _from, state) do
    {:reply, :ok, %{buffer: []}}
  end

  def handle_cast({:flush, documents}, state) do
    EmqEsStorage.Elasticsearch.index(
      "#{get_index_chat()}/message",
      documents
    )
    {:noreply, state}
  end

  def handle_info(:flush, state) do
    case state.buffer do
      [] -> {:noreply, state}
      _ ->
        GenServer.cast(self(), {:flush, state.buffer})
        {:noreply, %{buffer: []}}
    end
  end

  defp schedule_flush() do
    Process.send_after(self(), :flush, 500)
  end
end
