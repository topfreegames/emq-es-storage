defmodule EmqEsStorage.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [
      worker(Cachex, [:topic_cache, [default_ttl: :timer.minutes(5)], []])
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
        [name: :"redix_#{i}"]
      ], id: {Redix, i})
    end
    supervise(workers ++ children, strategy: :one_for_one)
  end
end
