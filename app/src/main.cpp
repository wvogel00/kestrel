#include "MainWindow.hpp"

#include <memory>
#include <stdexcept>

#include <QApplication>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>

namespace {

using kestrel::model::NodeSpec;
using kestrel::model::NodeType;

std::shared_ptr<NodeSpec> parseNode(const QJsonObject& object)
{
    const QString type = object.value("type").toString();
    auto node = std::make_shared<NodeSpec>();

    if (type == "box") {
        node->type = NodeType::Box;
        node->widthMm = object.value("width_mm").toDouble(-1.0);
        node->depthMm = object.value("depth_mm").toDouble(-1.0);
        node->heightMm = object.value("height_mm").toDouble(-1.0);

        if (node->widthMm <= 0.0 || node->depthMm <= 0.0 || node->heightMm <= 0.0) {
            throw std::runtime_error("Box dimensions must be greater than zero");
        }

        return node;
    }

    if (type == "cylinder") {
        node->type = NodeType::Cylinder;
        node->radiusMm = object.value("radius_mm").toDouble(-1.0);
        node->heightMm = object.value("height_mm").toDouble(-1.0);

        if (node->radiusMm <= 0.0 || node->heightMm <= 0.0) {
            throw std::runtime_error("Cylinder dimensions must be greater than zero");
        }

        return node;
    }

    if (type == "translate") {
        node->type = NodeType::Translate;
        node->xMm = object.value("x_mm").toDouble();
        node->yMm = object.value("y_mm").toDouble();
        node->zMm = object.value("z_mm").toDouble();

        const QJsonObject childObject = object.value("child").toObject();
        if (childObject.isEmpty()) {
            throw std::runtime_error("Translate node is missing child geometry");
        }
        node->child = parseNode(childObject);
        return node;
    }

    if (type == "union" || type == "cut") {
        node->type = type == "union" ? NodeType::Union : NodeType::Cut;

        const QJsonObject leftObject = object.value("left").toObject();
        const QJsonObject rightObject = object.value("right").toObject();
        if (leftObject.isEmpty() || rightObject.isEmpty()) {
            throw std::runtime_error("Boolean node is missing an operand");
        }

        node->left = parseNode(leftObject);
        node->right = parseNode(rightObject);
        return node;
    }

    throw std::runtime_error(
        QString("Unsupported geometry node type: %1").arg(type).toStdString());
}

std::shared_ptr<NodeSpec> loadModel(const QString& path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        throw std::runtime_error(
            QString("Cannot open model IR: %1").arg(path).toStdString());
    }

    QJsonParseError parseError;
    const QJsonDocument document =
        QJsonDocument::fromJson(file.readAll(), &parseError);

    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        throw std::runtime_error(
            QString("Invalid model IR: %1").arg(parseError.errorString()).toStdString());
    }

    const QJsonObject documentObject = document.object();
    if (documentObject.value("version").toInt() != 2) {
        throw std::runtime_error("Unsupported Kestrel model IR version");
    }

    const QJsonObject root = documentObject.value("root").toObject();
    if (root.isEmpty()) {
        throw std::runtime_error("Kestrel model IR has no root geometry");
    }

    return parseNode(root);
}

QString defaultModelPath()
{
    const QDir executableDirectory(QCoreApplication::applicationDirPath());
    return QDir::cleanPath(
        executableDirectory.filePath("../Resources/model.json"));
}

} // namespace

int main(int argc, char* argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName("Kestrel");
    QApplication::setOrganizationName("Kestrel");

    try {
        const QString modelPath =
            argc > 1 ? QString::fromLocal8Bit(argv[1]) : defaultModelPath();

        const std::shared_ptr<NodeSpec> model = loadModel(modelPath);
        qInfo().noquote() << "Kestrel model IR v2 loaded:" << modelPath;

        MainWindow window(*model);
        window.show();

        return app.exec();
    } catch (const std::exception& error) {
        qCritical() << "Kestrel failed to load its model:" << error.what();
        return 1;
    }
}
