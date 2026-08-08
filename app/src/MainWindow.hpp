#pragma once

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

    kestrel::occt::Viewer* viewer_ = nullptr;
};
