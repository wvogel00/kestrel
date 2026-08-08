#include "MainWindow.hpp"

#include <QAction>
#include <QDebug>
#include <QFileDialog>
#include <QKeySequence>
#include <QMenu>
#include <QMenuBar>
#include <QMessageBox>

#include <kestrel/occt/Viewer.hpp>

MainWindow::MainWindow(const kestrel::model::NodeSpec& model, QWidget* parent)
    : QMainWindow(parent)
{
    setWindowTitle("Kestrel");
    resize(1200, 800);

    viewer_ = new kestrel::occt::Viewer(model, this);
    setCentralWidget(viewer_);

    auto* fileMenu = menuBar()->addMenu("File");
    auto* viewMenu = menuBar()->addMenu("View");

    auto* exportAction = new QAction("Export...", this);
    // On macOS, Qt maps the portable Ctrl modifier to the Command key.
    exportAction->setShortcut(QKeySequence("Ctrl+E"));
    exportAction->setShortcutContext(Qt::ApplicationShortcut);
    fileMenu->addAction(exportAction);
    addAction(exportAction);
    connect(exportAction, &QAction::triggered, this, [this] {
        qInfo() << "Kestrel shortcut: Export";
        exportModel();
    });

    auto* displayModeAction = new QAction("Toggle Wireframe/Shaded", this);
    displayModeAction->setShortcut(QKeySequence(Qt::Key_P));
    displayModeAction->setShortcutContext(Qt::ApplicationShortcut);
    viewMenu->addAction(displayModeAction);
    addAction(displayModeAction);
    connect(displayModeAction, &QAction::triggered, this, [this] {
        qInfo() << "Kestrel shortcut: Toggle display mode";
        viewer_->toggleDisplayMode();
    });
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
