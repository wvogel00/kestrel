#include "MainWindow.hpp"

#include <kestrel/occt/Viewer.hpp>

MainWindow::MainWindow(QWidget* parent)
    : QMainWindow(parent)
{
    setWindowTitle("Kestrel");
    resize(1200, 800);

    auto* viewer = new kestrel::occt::Viewer(this);
    setCentralWidget(viewer);
}
