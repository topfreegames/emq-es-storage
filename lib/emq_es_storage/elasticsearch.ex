defmodule EmqEsStorage.Elasticsearch do
  require Logger

  use HTTPoison.Base
  require Poison

  @elasticsearch_url System.get_env("ES_URI") || "http://localhost:9200"

  def process_url(url) do
    @elasticsearch_url <> url
  end

  def perform({index, document}) do
    uri = "#{index}/message"
    Logger.info("Request for #{process_url(uri)}")
    index(
      uri,
      document
    )
  end

  def index(url, body) do
    post!(
      url,
      Poison.encode!(body),
      [{"Content-Type", "application/json"}],
      [hackney: [pool: :es_pool]]
    )
    :ok
  end

  def post!(url), do: post(url, [], [], hackney: [pool: :es_pool])

  def create_index_template() do
    post!(
      "/_template/chat_emqtt",
      File.read!(Path.join(:code.priv_dir(:emq_es_storage), "template.json")),
      [],
      hackney: [pool: :es_pool]
    )
  end

  @spec process_response_body(binary) :: term
  def process_response_body(body) do
    Poison.Parser.parse!(body)
  end
end
