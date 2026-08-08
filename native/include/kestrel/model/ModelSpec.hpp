#pragma once

#include <memory>

namespace kestrel::model {

enum class NodeType {
    Box,
    Cylinder,
    Translate,
    Union,
    Cut,
};

struct NodeSpec {
    NodeType type;

    // Box
    double widthMm = 0.0;
    double depthMm = 0.0;
    double heightMm = 0.0;

    // Cylinder
    double radiusMm = 0.0;

    // Translate
    double xMm = 0.0;
    double yMm = 0.0;
    double zMm = 0.0;

    // Recursive children
    std::shared_ptr<NodeSpec> child;
    std::shared_ptr<NodeSpec> left;
    std::shared_ptr<NodeSpec> right;
};

} // namespace kestrel::model
