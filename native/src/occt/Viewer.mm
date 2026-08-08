#include <kestrel/occt/Viewer.hpp>

#include <stdexcept>

#include <QKeyEvent>
#include <QMouseEvent>
#include <QPaintEngine>
#include <QPaintEvent>
#include <QResizeEvent>
#include <QWheelEvent>

#include <AIS_DisplayMode.hxx>
#include <AIS_Shape.hxx>
#include <Aspect_DisplayConnection.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <Cocoa_Window.hxx>
#include <OpenGl_GraphicDriver.hxx>
#include <Prs3d_Drawer.hxx>
#include <Quantity_NameOfColor.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

namespace kestrel::occt {

Viewer::Viewer(const kestrel::model::NodeSpec& model, QWidget* parent)
    : QWidget(parent)
{
    setAttribute(Qt::WA_NativeWindow);
    setAttribute(Qt::WA_PaintOnScreen);
    setAttribute(Qt::WA_NoSystemBackground);
    setMouseTracking(true);
    setFocusPolicy(Qt::StrongFocus);

    initializeOcct();
    displayModel(model);
}

QPaintEngine* Viewer::paintEngine() const
{
    return nullptr;
}

void Viewer::initializeOcct()
{
    const Handle(Aspect_DisplayConnection) displayConnection =
        new Aspect_DisplayConnection();

    const Handle(OpenGl_GraphicDriver) graphicDriver =
        new OpenGl_GraphicDriver(displayConnection);

    viewer_ = new V3d_Viewer(graphicDriver);
    viewer_->SetDefaultLights();
    viewer_->SetLightOn();

    context_ = new AIS_InteractiveContext(viewer_);
    context_->SetDisplayMode(AIS_Shaded, Standard_False);

    view_ = viewer_->CreateView();

    NSView* nativeView = reinterpret_cast<NSView*>(winId());
    const Handle(Cocoa_Window) cocoaWindow = new Cocoa_Window(nativeView);

    view_->SetWindow(cocoaWindow);
    if (!cocoaWindow->IsMapped()) {
        cocoaWindow->Map();
    }

    view_->SetBackgroundColor(Quantity_NOC_GRAY20);
    view_->MustBeResized();
}

TopoDS_Shape Viewer::evaluate(const kestrel::model::NodeSpec& node) const
{
    using kestrel::model::NodeType;

    switch (node.type) {
    case NodeType::Box:
        return BRepPrimAPI_MakeBox(
            node.widthMm,
            node.depthMm,
            node.heightMm).Shape();

    case NodeType::Cylinder:
        return BRepPrimAPI_MakeCylinder(
            node.radiusMm,
            node.heightMm).Shape();

    case NodeType::Translate: {
        if (!node.child) {
            throw std::runtime_error("Translate node is missing child geometry");
        }

        gp_Trsf transform;
        transform.SetTranslation(gp_Vec(node.xMm, node.yMm, node.zMm));

        return BRepBuilderAPI_Transform(
            evaluate(*node.child),
            transform,
            Standard_True).Shape();
    }

    case NodeType::Union:
        if (!node.left || !node.right) {
            throw std::runtime_error("Union node is missing an operand");
        }
        return BRepAlgoAPI_Fuse(
            evaluate(*node.left),
            evaluate(*node.right)).Shape();

    case NodeType::Cut:
        if (!node.left || !node.right) {
            throw std::runtime_error("Cut node is missing an operand");
        }
        return BRepAlgoAPI_Cut(
            evaluate(*node.left),
            evaluate(*node.right)).Shape();
    }

    throw std::runtime_error("Unknown Kestrel geometry node");
}

void Viewer::displayModel(const kestrel::model::NodeSpec& model)
{
    const TopoDS_Shape shape = evaluate(model);
    if (shape.IsNull()) {
        throw std::runtime_error("OCCT produced a null shape");
    }

    const Handle(AIS_Shape) presentation = new AIS_Shape(shape);

    // CAD-style shaded presentation: filled faces with visible boundaries.
    presentation->SetDisplayMode(AIS_Shaded);
    presentation->SetColor(Quantity_NOC_LIGHTSTEELBLUE);
    presentation->Attributes()->SetFaceBoundaryDraw(Standard_True);

    context_->Display(presentation, Standard_True);
    view_->FitAll();
    view_->ZFitAll();
    view_->Redraw();
}

void Viewer::toggleDisplayMode()
{
    if (context_.IsNull() || view_.IsNull()) {
        return;
    }

    isShaded_ = !isShaded_;
    context_->SetDisplayMode(
        isShaded_ ? AIS_Shaded : AIS_WireFrame,
        Standard_True);
    view_->Redraw();
}

void Viewer::paintEvent(QPaintEvent* event)
{
    Q_UNUSED(event);
    if (!view_.IsNull()) {
        view_->Redraw();
    }
}

void Viewer::resizeEvent(QResizeEvent* event)
{
    QWidget::resizeEvent(event);
    if (!view_.IsNull()) {
        view_->MustBeResized();
        view_->Redraw();
    }
}

void Viewer::mousePressEvent(QMouseEvent* event)
{
    lastMousePosition_ = event->position().toPoint();
    setFocus(Qt::MouseFocusReason);

    if (event->button() == Qt::LeftButton && !context_.IsNull()) {
        context_->MoveTo(
            lastMousePosition_.x(),
            lastMousePosition_.y(),
            view_,
            Standard_True);
        context_->SelectDetected();
    }
}

void Viewer::mouseMoveEvent(QMouseEvent* event)
{
    const QPoint position = event->position().toPoint();

    if ((event->buttons() & Qt::LeftButton) && !view_.IsNull()) {
        const QPoint delta = position - lastMousePosition_;
        view_->Rotate(
            delta.y() * 0.01,
            delta.x() * 0.01,
            0.0,
            Standard_True);
    } else if (!context_.IsNull()) {
        context_->MoveTo(position.x(), position.y(), view_, Standard_True);
    }

    lastMousePosition_ = position;
}

void Viewer::wheelEvent(QWheelEvent* event)
{
    if (view_.IsNull()) {
        return;
    }

    const int delta = event->angleDelta().y();
    const double factor = delta > 0 ? 0.8 : 1.25;
    view_->SetZoom(factor, Standard_True);
}

void Viewer::keyPressEvent(QKeyEvent* event)
{
    if (event->key() == Qt::Key_P && !event->isAutoRepeat()) {
        toggleDisplayMode();
        event->accept();
        return;
    }

    QWidget::keyPressEvent(event);
}

} // namespace kestrel::occt
