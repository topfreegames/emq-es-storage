defmodule EmqEsStorage do
  use Application

  def start(_type, _args) do
    {:ok, supervisor} = EmqEsStorage.Supervisor.start_link()
    :ok = EmqEsStorage.Body.load([])
    {:ok, supervisor}
  end

  def stop(_app) do
    EmqEsStorage.Body.unload()
  end
end
