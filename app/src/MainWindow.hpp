#pragma once

#include <QMainWindow>

#include <kestrel/model/ModelSpec.hpp>

class MainWindow final : public QMainWindow {
public:
    explicit MainWindow(const kestrel::model::BoxSpec& boxSpec,
                        QWidget* parent = nullptr);
};
