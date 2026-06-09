package terraform.tags

import rego.v1

required_tags := {
  "env",
  "owner",
  "costCenter",
  "product",
  "dataClassification",
  "confidentiality",
  "managedBy",
  "repo",
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.mode == "managed"
  startswith(resource.type, "azurerm_")
  not delete_only(resource.change.actions)
  has_tags_attribute(resource.change.after)
  tags := resource_tags(resource.change.after)
  missing := sort([tag | some tag in required_tags; missing_required_tag(tags, tag)])
  count(missing) > 0
  msg := sprintf("%s is missing required tags: %s", [resource.address, concat(", ", missing)])
}

delete_only(actions) if {
  actions == ["delete"]
}

missing_required_tag(tags, tag) if {
  value := object.get(tags, tag, "")
  value == ""
}

has_tags_attribute(after) if {
  object.get(after, "tags", "__missing__") != "__missing__"
}

resource_tags(after) := tags if {
  tags := object.get(after, "tags", {})
  is_object(tags)
}

resource_tags(after) := {} if {
  tags := object.get(after, "tags", {})
  not is_object(tags)
}
