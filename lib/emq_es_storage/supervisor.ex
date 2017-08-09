defmodule EmqEsStorage.Supervisor do
  use Supervisor
  require HTTPoison

  def start_link do
    Supervisor.start_link(__MODULE__, [
      worker(Cachex, [:topic_cache, [default_ttl: :timer.minutes(5)], []]),
      :hackney_pool.child_spec(:es_pool, [timeout: 15000, max_connections: 100])
    ])
  end

  def init(children) do
    host = System.get_env("REDIS_HOST") || "localhost"
    port = String.to_integer(System.get_env("REDIS_PORT") || "6379")
    password = System.get_env("REDIS_PASSWORD") || nil
    pool_size = String.to_integer(System.get_env("REDIS_POOL_SIZE") || "5")
    workers = for i <- 0..(pool_size - 1) do
      worker(Redix, [
        [host: host, port: port, password: password],
        [name: :"emq_es_storage_redix_#{i}"]
      ], id: {:es_storage_redix, i})
    end

    es_workers = for i <- 0..(9) do
      worker(EmqEsStorage.Server, [
        [name: :"emq_es_storage_server_#{i}"]
      ], id: {:emq_es_storage_server, i})
    end

    # :ok = :hackney_pool.start_pool(:es_pool, [timeout: 15000, max_connections: 100])
    HTTPoison.start()

    supervise(workers ++ children ++ es_workers, strategy: :one_for_one)
  end
end
