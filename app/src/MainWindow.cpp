#include "MainWindow.hpp"

#include <kestrel/occt/Viewer.hpp>

MainWindow::MainWindow(const kestrel::model::BoxSpec& boxSpec, QWidget* parent)
    : QMainWindow(parent)
{
    setWindowTitle("Kestrel");
    resize(1200, 800);

    auto* viewer = new kestrel::occt::Viewer(boxSpec, this);
    setCentralWidget(viewer);
}
