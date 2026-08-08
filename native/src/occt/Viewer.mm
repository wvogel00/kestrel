#include <kestrel/occt/Viewer.hpp>

#include <QMouseEvent>
#include <QPaintEngine>
#include <QPaintEvent>
#include <QResizeEvent>
#include <QWheelEvent>

#include <AIS_Shape.hxx>
#include <Aspect_DisplayConnection.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <Cocoa_Window.hxx>
#include <OpenGl_GraphicDriver.hxx>

namespace kestrel::occt {

Viewer::Viewer(const kestrel::model::BoxSpec& boxSpec, QWidget* parent)
    : QWidget(parent)
{
    setAttribute(Qt::WA_NativeWindow);
    setAttribute(Qt::WA_PaintOnScreen);
    setAttribute(Qt::WA_NoSystemBackground);
    setMouseTracking(true);
    setFocusPolicy(Qt::StrongFocus);

    initializeOcct();
    displayBox(boxSpec);
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

void Viewer::displayBox(const kestrel::model::BoxSpec& boxSpec)
{
    const TopoDS_Shape box = BRepPrimAPI_MakeBox(
        boxSpec.widthMm,
        boxSpec.depthMm,
        boxSpec.heightMm).Shape();

    const Handle(AIS_Shape) presentation = new AIS_Shape(box);

    context_->Display(presentation, Standard_True);
    view_->FitAll();
    view_->ZFitAll();
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

} // namespace kestrel::occt
