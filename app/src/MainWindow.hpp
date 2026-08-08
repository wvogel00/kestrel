#pragma once

#include <QElapsedTimer>
#include <QMainWindow>

#include <kestrel/model/ModelSpec.hpp>

namespace kestrel::occt {
class Viewer;
}

class MainWindow final : public QMainWindow {
public:
    explicit MainWindow(const kestrel::model::NodeSpec& model,
                        QWidget* parent = nullptr);

private:
    void exportModel();
    void handleAxisShortcut(char axis);

    kestrel::occt::Viewer* viewer_ = nullptr;

    QElapsedTimer axisShortcutTimer_;
    char lastAxisShortcut_ = '\0';
    static constexpr qint64 kAxisDoublePressMs = 400;
};
