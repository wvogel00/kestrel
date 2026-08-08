#include "MainWindow.hpp"

#include <QFileDialog>
#include <QKeySequence>
#include <QMessageBox>
#include <QShortcut>

#include <kestrel/occt/Viewer.hpp>

MainWindow::MainWindow(const kestrel::model::NodeSpec& model, QWidget* parent)
    : QMainWindow(parent)
{
    setWindowTitle("Kestrel");
    resize(1200, 800);

    viewer_ = new kestrel::occt::Viewer(model, this);
    setCentralWidget(viewer_);

    auto* displayModeShortcut = new QShortcut(QKeySequence(Qt::Key_P), this);
    displayModeShortcut->setContext(Qt::ApplicationShortcut);
    connect(displayModeShortcut, &QShortcut::activated,
            viewer_, &kestrel::occt::Viewer::toggleDisplayMode);

    auto* exportShortcut = new QShortcut(QKeySequence(Qt::META | Qt::Key_E), this);
    exportShortcut->setContext(Qt::ApplicationShortcut);
    connect(exportShortcut, &QShortcut::activated,
            this, &MainWindow::exportModel);
}

void MainWindow::exportModel()
{
    QString selectedFilter = "STEP files (*.step *.stp)";
    QString filePath = QFileDialog::getSaveFileName(
        this,
        "Export Kestrel model",
        QString(),
        "STEP files (*.step *.stp);;STL files (*.stl)",
        &selectedFilter);

    if (filePath.isEmpty()) {
        return;
    }

    bool success = false;

    if (selectedFilter.startsWith("STEP")) {
        if (!filePath.endsWith(".step", Qt::CaseInsensitive)
            && !filePath.endsWith(".stp", Qt::CaseInsensitive)) {
            filePath += ".step";
        }
        success = viewer_->exportStep(filePath.toStdString());
    } else {
        if (!filePath.endsWith(".stl", Qt::CaseInsensitive)) {
            filePath += ".stl";
        }
        success = viewer_->exportStl(filePath.toStdString());
    }

    if (!success) {
        QMessageBox::critical(
            this,
            "Export failed",
            QString("Failed to export model to:\n%1").arg(filePath));
    }
}
