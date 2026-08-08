#include "MainWindow.hpp"

#include <stdexcept>

#include <QApplication>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>

namespace {

kestrel::model::BoxSpec loadModel(const QString& path)
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
    if (documentObject.value("version").toInt() != 1) {
        throw std::runtime_error("Unsupported Kestrel model IR version");
    }

    const QJsonObject root = documentObject.value("root").toObject();
    if (root.value("type").toString() != "box") {
        throw std::runtime_error("M2 supports only a box root primitive");
    }

    kestrel::model::BoxSpec box {
        .widthMm = root.value("width_mm").toDouble(-1.0),
        .depthMm = root.value("depth_mm").toDouble(-1.0),
        .heightMm = root.value("height_mm").toDouble(-1.0),
    };

    if (box.widthMm <= 0.0 || box.depthMm <= 0.0 || box.heightMm <= 0.0) {
        throw std::runtime_error("Box dimensions must be greater than zero");
    }

    return box;
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

        const kestrel::model::BoxSpec boxSpec = loadModel(modelPath);

        qInfo().noquote()
            << QString("Kestrel model: box %1 x %2 x %3 mm")
                   .arg(boxSpec.widthMm)
                   .arg(boxSpec.depthMm)
                   .arg(boxSpec.heightMm);

        MainWindow window(boxSpec);
        window.show();

        return app.exec();
    } catch (const std::exception& error) {
        qCritical() << "Kestrel failed to load its model:" << error.what();
        return 1;
    }
}
