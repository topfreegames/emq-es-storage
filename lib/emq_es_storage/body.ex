defmodule EmqEsStorage.Body do
  require Logger
  require EmqEsStorage.Shared
  import EmqEsStorage.Redis
  import Tirexs.HTTP

  def hook_add(a, b, c) do
    :emqttd_hooks.add(a, b, c)
  end

  def hook_del(a, b) do
    :emqttd_hooks.delete(a, b)
  end

  def load(env) do
    hook_add(
      :"message.publish",
      &EmqEsStorage.Body.on_message_publish/2,
      [env]
    )

    post!(
      "/_template/chat_emqtt",
      File.read!(Path.join(:code.priv_dir(:emq_es_storage), "template.json"))
    )

    :ok
  end

  def unload do
    hook_del(
      :"message.publish",
      &EmqEsStorage.Body.on_message_publish/2
    )
  end

  def get_index_chat do
    "/chat-#{Date.utc_today}"
  end

  def process_message(message, "$SYS/" <> _, _), do: {:ok, message}

  def process_message(message, topic, payload) do
    case match_topic?(topic) do
      true ->
        store_on_es(topic, payload)
        {:ok, message}
      false -> {:ok, message}
    end
  end

  def on_message_publish(message, _env) do
    process_message(
      message,
      EmqEsStorage.Shared.mqtt_message(message, :topic),
      EmqEsStorage.Shared.mqtt_message(message, :payload)
    )
  end

  def get_topics do
    {_, topics} = Cachex.get(:topic_cache, "emqtt-topic-filter", fallback: fn(_key) ->
      result = command(["SMEMBERS", "emqtt-topic-filter"])
      Logger.info fn ->
        "[emq_es_storage] Updating matched topics: #{result}"
      end
      result
    end)
    topics
  end

  def match_topic?(topic) do
    get_topics()
    |> Enum.any?( fn(x) ->
        transform_in_regex(x) |> Regex.match?(topic)
       end)
  end

  def transform_in_regex(topic) do
    topic
    |> String.replace("+", "[^/]+")
    |> String.replace("#", ".*")
    |> Regex.compile!
  end

  def store_on_es(topic, payload) do
    post!(
      "#{get_index_chat()}/message",
      [topic: topic, payload: payload, timestamp: DateTime.utc_now |> DateTime.to_iso8601]
    )
  end
end
