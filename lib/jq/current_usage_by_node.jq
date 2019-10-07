[.[] | {"key": .id, "value": .result}] | from_entries | (."node-metrics".items[] | {name: .metadata.name, cpu: .usage.cpu, memory: .usage.memory}) as $node | $node
