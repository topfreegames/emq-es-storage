# emq-es-storage

Stores matched topics messages on elasticsearch.

## Adding topics:
```
sadd emqtt-topic-filter chat/+/room/+
```

## configuration

* REDIS_HOST
* REDIS_PORT
* REDIS_PASSWORD
* REDIS_POOL_SIZE
* ES_URI
