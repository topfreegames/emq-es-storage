defmodule EmqEsStorageTest do
  use ExUnit.Case
  require EmqEsStorage.Shared
  require EmqEsStorage.Redis
  require EmqEsStorage.Elasticsearch

  setup_all do
    {:ok, _} = Cachex.Application.start(nil, nil)
    :emqttd_hooks.start_link()
    {:ok, _} = EmqEsStorage.start(nil, nil)
    :ok
  end

  def get_wait_time do
    {result, _} = Integer.parse(System.get_env("WAIT_FOR") || "500")
    result
  end

  setup do
    EmqEsStorage.Elasticsearch.delete("/chat-#{Date.utc_today}")
    EmqEsStorage.Elasticsearch.put("/chat-#{Date.utc_today}")
    Cachex.clear(:topic_cache)
    EmqEsStorage.Redis.command(
      ["sadd", "emqtt-topic-filter", "chat/+/room/+"]
    )
    :ok
  end

  def get_message(topic) do
    EmqEsStorage.Shared.mqtt_message(
      topic: topic,
      payload: UUID.uuid4()
    )
  end

  def get_payload(record) do
    EmqEsStorage.Shared.mqtt_message(record, :payload)
  end

  def refresh_index, do: EmqEsStorage.Elasticsearch.post!("/chat-*/_refresh")

  test "when $SYS topics should not write to ES" do
    sys_message = get_message("$SYS/something/important")
    EmqEsStorage.Body.on_message_publish(sys_message, [])
    :timer.sleep(get_wait_time())
    refresh_index()

    {:ok, result} = EmqEsStorage.Elasticsearch.get(
      "/chat-*/_search?q=payload:#{get_payload(sys_message)}"
    )
    assert result.body["hits"]["total"] == 0
  end

  test "when topic from matched topic, should store on ES" do
    message = get_message("chat/my_clan/room/my_room")
    EmqEsStorage.Body.on_message_publish(message, [])
    :timer.sleep(get_wait_time())
    refresh_index()

    {:ok, result} = EmqEsStorage.Elasticsearch.get(
      "/chat-*/_search?q=payload:#{get_payload(message)}"
    )

    assert result.body["hits"]["total"] == 1
  end

  test "when topic from matched topic, should buffer" do
    message = get_message("chat/my_clan/room/my_room")
    EmqEsStorage.Body.on_message_publish(message, [])
    EmqEsStorage.Body.on_message_publish(message, [])
    EmqEsStorage.Body.on_message_publish(message, [])
    :timer.sleep(get_wait_time())
    refresh_index()

    {:ok, result} = EmqEsStorage.Elasticsearch.get(
      "/chat-*/_search?q=payload:#{get_payload(message)}"
    )

    assert result.body["hits"]["total"] == 3
  end

  test "when topic from not matched topic, should not store on ES" do
    message = get_message("not/matched_topic")
    EmqEsStorage.Body.on_message_publish(message, [])
    :timer.sleep(get_wait_time())
    refresh_index()

    {:ok, result} = EmqEsStorage.Elasticsearch.get(
      "/chat-*/_search?q=payload:#{get_payload(message)}"
    )

    assert result.body["hits"]["total"] == 0
  end

  test "when topic list cached" do
    topic = "now/matched/+"
    Cachex.set!(:topic_cache, "emqtt-topic-filter", [topic])
    message = get_message("now/matched/topic")
    EmqEsStorage.Body.on_message_publish(message, [])
    :timer.sleep(get_wait_time())
    refresh_index()

    {:ok, result} = EmqEsStorage.Elasticsearch.get(
      "/chat-*/_search?q=payload:#{get_payload(message)}"
    )

    assert result.body["hits"]["total"] == 1
  end

  test "when topic list is empty" do
    topic = "not/matched/+"
    message = get_message(topic)
    EmqEsStorage.Redis.command(["DEL", "emqtt-topic-filter"])
    EmqEsStorage.Body.on_message_publish(message, [])
    :timer.sleep(get_wait_time())
    refresh_index()

    {:ok, result} = EmqEsStorage.Elasticsearch.get(
      "/chat-*/_search?q=payload:#{get_payload(message)}"
    )

    assert result.body["hits"]["total"] == 0
  end
end
