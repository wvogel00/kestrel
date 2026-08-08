#include "MainWindow.hpp"

#include <QAction>
#include <QDebug>
#include <QEvent>
#include <QFileDialog>
#include <QInputDialog>
#include <QKeySequence>
#include <QMenu>
#include <QMenuBar>
#include <QMessageBox>
#include <QMouseEvent>
#include <QStatusBar>

#include <kestrel/occt/Viewer.hpp>

MainWindow::MainWindow(const kestrel::model::NodeSpec& model, QWidget* parent)
    : QMainWindow(parent)
{
    setWindowTitle("Kestrel");
    resize(1200, 800);

    viewer_ = new kestrel::occt::Viewer(model, this);
    setCentralWidget(viewer_);
    viewer_->installEventFilter(this);

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

    auto* dimensionAction = new QAction("Sketch Dimension", this);
    dimensionAction->setShortcut(QKeySequence(Qt::Key_D));
    dimensionAction->setShortcutContext(Qt::ApplicationShortcut);
    createMenu->addAction(dimensionAction);
    addAction(dimensionAction);
    connect(dimensionAction, &QAction::triggered,
            this, &MainWindow::dimensionSelection);

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

bool MainWindow::eventFilter(QObject* watched, QEvent* event)
{
    if (watched == viewer_ && viewer_->isSketchMode()) {
        if (event->type() == QEvent::MouseMove) {
            const auto* mouseEvent = static_cast<QMouseEvent*>(event);
            viewer_->handleSketchMouseMove(mouseEvent->position().toPoint());
            return true;
        }

        if (event->type() == QEvent::MouseButtonPress) {
            const auto* mouseEvent = static_cast<QMouseEvent*>(event);
            if (mouseEvent->button() == Qt::LeftButton) {
                viewer_->handleSketchMousePress(mouseEvent->position().toPoint());
                return true;
            }
        }
    }

    return QMainWindow::eventFilter(watched, event);
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

    viewer_->enableSketchInteraction();
    statusBar()->showMessage(
        "Sketch: hover a body vertex to snap (yellow), then click two opposite rectangle corners. Select a sketch edge and press D to dimension. Esc finishes.");
}

void MainWindow::exitSketch()
{
    if (!viewer_->isSketchMode()) {
        return;
    }

    qInfo() << "Kestrel shortcut: Exit sketch";
    viewer_->disableSketchInteraction();
    viewer_->exitSketchMode();
    statusBar()->showMessage(
        "Sketch finished. Select the orange profile and press E to extrude.",
        5000);
}

void MainWindow::dimensionSelection()
{
    qInfo() << "Kestrel shortcut: Sketch dimension";

    if (!viewer_->isSketchMode()) {
        QMessageBox::information(
            this,
            "Sketch Dimension",
            "Dimension constraints are available while editing a sketch.");
        return;
    }

    const double currentLength = viewer_->selectedSketchEdgeLength();
    if (currentLength <= 0.0) {
        QMessageBox::information(
            this,
            "Sketch Dimension",
            "Select one of the orange rectangle edges, then press D.");
        return;
    }

    bool accepted = false;
    const double lengthMm = QInputDialog::getDouble(
        this,
        "Sketch Dimension",
        "Length [mm]:",
        currentLength,
        0.001,
        100000.0,
        3,
        &accepted);

    if (!accepted) {
        return;
    }

    if (!viewer_->setSelectedSketchDimension(lengthMm)) {
        QMessageBox::critical(
            this,
            "Sketch Dimension",
            "Could not apply the dimension constraint to the selected edge.");
        return;
    }

    statusBar()->showMessage(
        QString("Sketch dimension constrained to %1 mm").arg(lengthMm),
        4000);
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
