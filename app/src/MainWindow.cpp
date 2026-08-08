#include "MainWindow.hpp"

#include <QAction>
#include <QDebug>
#include <QFileDialog>
#include <QInputDialog>
#include <QKeySequence>
#include <QMenu>
#include <QMenuBar>
#include <QMessageBox>
#include <QStatusBar>

#include <kestrel/occt/Viewer.hpp>

MainWindow::MainWindow(const kestrel::model::NodeSpec& model, QWidget* parent)
    : QMainWindow(parent)
{
    setWindowTitle("Kestrel");
    resize(1200, 800);

    viewer_ = new kestrel::occt::Viewer(model, this);
    setCentralWidget(viewer_);

    auto* fileMenu = menuBar()->addMenu("File");
    auto* editMenu = menuBar()->addMenu("Edit");
    auto* viewMenu = menuBar()->addMenu("View");
    auto* createMenu = menuBar()->addMenu("Create");

    auto* exportAction = new QAction("Export...", this);
    exportAction->setShortcut(QKeySequence("Ctrl+E"));
    exportAction->setShortcutContext(Qt::ApplicationShortcut);
    fileMenu->addAction(exportAction);
    addAction(exportAction);
    connect(exportAction, &QAction::triggered, this, [this] {
        qInfo() << "Kestrel shortcut: Export";
        exportModel();
    });

    auto* undoAction = new QAction("Undo", this);
    undoAction->setShortcut(QKeySequence::Undo);
    undoAction->setShortcutContext(Qt::ApplicationShortcut);
    editMenu->addAction(undoAction);
    addAction(undoAction);
    connect(undoAction, &QAction::triggered, this, [this] {
        qInfo() << "Kestrel shortcut: Undo";
        if (viewer_->undoLastEdit()) {
            statusBar()->showMessage("Undid last geometry edit", 3000);
        } else {
            statusBar()->showMessage("Nothing to undo", 2000);
        }
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

    viewMenu->addSeparator();

    auto addAxisAction = [this, viewMenu](const QString& title,
                                          Qt::Key key,
                                          char axis) {
        auto* action = new QAction(title, this);
        action->setShortcut(QKeySequence(key));
        action->setShortcutContext(Qt::ApplicationShortcut);
        viewMenu->addAction(action);
        addAction(action);
        connect(action, &QAction::triggered, this, [this, axis] {
            handleAxisShortcut(axis);
        });
    };

    addAxisAction("View along X axis (+X / double: -X)", Qt::Key_X, 'x');
    addAxisAction("View along Y axis (+Y / double: -Y)", Qt::Key_Y, 'y');
    addAxisAction("View along Z axis (+Z / double: -Z)", Qt::Key_Z, 'z');

    auto* sketchAction = new QAction("Start Sketch on Selected Face", this);
    sketchAction->setShortcut(QKeySequence(Qt::Key_S));
    sketchAction->setShortcutContext(Qt::ApplicationShortcut);
    createMenu->addAction(sketchAction);
    addAction(sketchAction);
    connect(sketchAction, &QAction::triggered,
            this, &MainWindow::startSketch);

    auto* extrudeAction = new QAction("Extrude Selected Face/Profile", this);
    extrudeAction->setShortcut(QKeySequence(Qt::Key_E));
    extrudeAction->setShortcutContext(Qt::ApplicationShortcut);
    createMenu->addAction(extrudeAction);
    addAction(extrudeAction);
    connect(extrudeAction, &QAction::triggered,
            this, &MainWindow::extrudeSelection);

    auto* exitSketchAction = new QAction("Exit Sketch", this);
    exitSketchAction->setShortcut(QKeySequence(Qt::Key_Escape));
    exitSketchAction->setShortcutContext(Qt::ApplicationShortcut);
    createMenu->addAction(exitSketchAction);
    addAction(exitSketchAction);
    connect(exitSketchAction, &QAction::triggered,
            this, &MainWindow::exitSketch);
}

void MainWindow::handleAxisShortcut(char axis)
{
    const bool isDoublePress =
        axisShortcutTimer_.isValid()
        && lastAxisShortcut_ == axis
        && axisShortcutTimer_.elapsed() <= kAxisDoublePressMs;

    if (isDoublePress) {
        qInfo() << "Kestrel view:" << axis << "negative";
        viewer_->setAxisView(axis, false);
        axisShortcutTimer_.invalidate();
        lastAxisShortcut_ = '\0';
        return;
    }

    qInfo() << "Kestrel view:" << axis << "positive";
    viewer_->setAxisView(axis, true);

    lastAxisShortcut_ = axis;
    axisShortcutTimer_.restart();
}

void MainWindow::startSketch()
{
    qInfo() << "Kestrel shortcut: Start sketch";
    if (!viewer_->beginSketchOnSelectedFace()) {
        QMessageBox::information(
            this,
            "Start Sketch",
            "Select a planar face first, then press S.\n\n"
            "The current sketch prototype supports planar faces only.");
        return;
    }

    statusBar()->showMessage(
        "Sketch mode: click two opposite corners to create a rectangle. Press Esc to finish.");
}

void MainWindow::exitSketch()
{
    if (!viewer_->isSketchMode()) {
        return;
    }

    qInfo() << "Kestrel shortcut: Exit sketch";
    viewer_->exitSketchMode();
    statusBar()->showMessage(
        "Sketch finished. Select the orange profile and press E to extrude.",
        5000);
}

void MainWindow::extrudeSelection()
{
    qInfo() << "Kestrel shortcut: Extrude";

    if (!viewer_->canExtrudeSelection()) {
        QMessageBox::information(
            this,
            "Extrude",
            "Select an existing planar face or a sketch profile first, then press E.");
        return;
    }

    bool accepted = false;
    const double distanceMm = QInputDialog::getDouble(
        this,
        "Extrude",
        "Distance [mm]\nPositive = add, negative = cut:",
        10.0,
        -100000.0,
        100000.0,
        3,
        &accepted);

    if (!accepted) {
        return;
    }

    viewer_->pushUndoState();

    if (!viewer_->extrudeSelected(distanceMm)) {
        viewer_->undoLastEdit();
        QMessageBox::critical(
            this,
            "Extrude failed",
            "The selected profile could not be extruded.\n"
            "Only planar faces are supported in this prototype.");
        return;
    }

    statusBar()->showMessage(
        QString("Extruded %1 mm").arg(distanceMm),
        4000);
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
