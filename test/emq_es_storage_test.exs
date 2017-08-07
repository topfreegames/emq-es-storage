defmodule EmqEsStorageTest do
  use ExUnit.Case
  require EmqEsStorage.MqttMessage
  require Tirexs.HTTP
  require EmqEsStorage.Redis

  setup_all do
    :emqttd_hooks.start_link()
    Cachex.Application.start(nil, nil)
    {:ok, _} = EmqEsStorage.start(nil, nil)
    Tirexs.HTTP.put("/chat-#{Date.utc_today}")
    EmqEsStorage.Redis.command(
      ["sadd", "emqtt-topic-filter", "chat/+/room/+"]
    )
    :ok
  end

  def get_message(topic) do
    %EmqEsStorage.MqttMessage{
      topic: topic,
      payload: UUID.uuid4()
    }
  end

  def refresh_index, do: Tirexs.HTTP.post!("/chat-*/_refresh")

  test "when $SYS topics should not write to ES" do
    sys_message = get_message("$SYS/something/important")
    EmqEsStorage.Body.on_message_publish(sys_message, [])

    refresh_index()

    {:ok, 200, result} = Tirexs.HTTP.get(
      "/chat-*/_search?q=payload:#{sys_message.payload}"
    )
    assert result.hits.total == 0
  end

  test "when topic from matched topic, shoud store on ES" do
    message = get_message("chat/my_clan/room/my_room")
    EmqEsStorage.Body.on_message_publish(message, [])

    refresh_index()

    {:ok, 200, result} = Tirexs.HTTP.get(
      "/chat-*/_search?q=payload:#{message.payload}"
    )

    assert result.hits.total == 1
  end

  test "when topic from not matched topic, shoud not store on ES" do
    message = get_message("not/matched_topic")
    EmqEsStorage.Body.on_message_publish(message, [])

    refresh_index()

    {:ok, 200, result} = Tirexs.HTTP.get(
      "/chat-*/_search?q=payload:#{message.payload}"
    )

    assert result.hits.total == 0
  end
end