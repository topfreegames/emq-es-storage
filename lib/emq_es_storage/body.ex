defmodule EmqEsStorage.Body do
  require Logger
  require EmqEsStorage.MqttMessage
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

  def on_message_publish(message = %EmqEsStorage.MqttMessage{topic: <<"$SYS/">> <> _ }, _env), do: {:ok, message}

  def on_message_publish(message = %EmqEsStorage.MqttMessage{}, _env) do
    case match_topic?(message.topic) do
      true ->
        store_on_es(message)
        {:ok, message}
      false -> {:ok, message}
    end
  end

  def get_topics do
    result = command(["SMEMBERS", "emqtt-topic-filter"])
    Cachex.set(:topic_cache, "emqtt-topic-filter", "asdasd")
    # {:loaded, result} = Cachex.get(:topic_cache, "emqtt-topic-filter", fallback: fn(_key) ->
      # command(["SMEMBERS", "emqtt-topic-filter"])
    # end)
    result
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

  def store_on_es(message) do
    post!(
      "#{get_index_chat()}/message",
      [topic: message.topic, payload: message.payload]
    )
  end
end
