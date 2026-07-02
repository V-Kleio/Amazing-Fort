class_name Discovery
extends Object

## Find parent of specific type (walk up tree)
static func find_parent_of_type(node: Node, type: Variant) -> Node:
    var current: Node = node.get_parent()
    while current:
        if is_instance_of(current, type):
            return current
        current = current.get_parent()
    return null

## Find child of specific type (first occurrence, recursive)
static func find_child_of_type(node: Node, type: Variant) -> Node:
    for child in node.get_children():
        if is_instance_of(child, type):
            return child
        var found: Node = find_child_of_type(child, type)
        if found:
            return found
    return null

## Find all children of specific type (recursive)
static func find_children_of_type(node: Node, type: Variant) -> Array[Node]:
    var children: Array[Node] = []
    for child in node.get_children():
        if is_instance_of(child, type):
            children.append(child)
        children.append_array(find_children_of_type(child, type))
    return children

## Find sibling component (same parent)
static func get_component(node: Node, type: Variant) -> Node:
    var parent: Node = node.get_parent()
    if not parent:
        return null

    for sibling in parent.get_children():
        if is_instance_of(sibling, type):
            return sibling
    return null

## Find all sibling components of type
static func get_all_components(node: Node, type: Variant) -> Array[Node]:
    var results: Array[Node] = []
    var parent: Node = node.get_parent()
    if not parent:
        return results

    for sibling in parent.get_children():
        if is_instance_of(sibling, type):
            results.append(sibling)
    return results

## Register a node into target's metadata
static func register_node(requester: Node, target: Node, key: String) -> void:
    if target:
        target.set_meta(key, requester)

## Get registered node from target's metadata
static func get_registered(target: Node, key: String) -> Node:
    if target and target.has_meta(key):
        return target.get_meta(key)
    return null