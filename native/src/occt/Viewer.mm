#include <kestrel/occt/Viewer.hpp>

#include <cmath>
#include <stdexcept>

#include <QMouseEvent>
#include <QPaintEngine>
#include <QPaintEvent>
#include <QResizeEvent>
#include <QWheelEvent>

#include <AIS_DisplayMode.hxx>
#include <AIS_Shape.hxx>
#include <Aspect_DisplayConnection.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <Cocoa_Window.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <OpenGl_GraphicDriver.hxx>
#include <Prs3d_Drawer.hxx>
#include <Quantity_NameOfColor.hxx>
#include <STEPControl_StepModelType.hxx>
#include <STEPControl_Writer.hxx>
#include <StlAPI_Writer.hxx>
#include <TopAbs_Orientation.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Wire.hxx>
#include <V3d_TypeOfOrientation.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

namespace kestrel::occt {
namespace {

gp_Dir outwardNormal(const TopoDS_Face& face)
{
    BRepAdaptor_Surface surface(face, Standard_True);
    if (surface.GetType() != GeomAbs_Plane) {
        throw std::runtime_error("Only planar faces are supported in this prototype");
    }

    gp_Dir normal = surface.Plane().Axis().Direction();
    if (face.Orientation() == TopAbs_REVERSED) {
        normal.Reverse();
    }
    return normal;
}

} // namespace

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
    currentShape_ = evaluate(model);
    if (currentShape_.IsNull()) {
        throw std::runtime_error("OCCT produced a null shape");
    }

    presentation_ = new AIS_Shape(currentShape_);
    presentation_->SetColor(Quantity_NOC_LIGHTSTEELBLUE);
    presentation_->Attributes()->SetFaceBoundaryDraw(Standard_True);

    context_->Display(presentation_, AIS_Shaded, 0, Standard_True);
    context_->Activate(presentation_, AIS_Shape::SelectionMode(TopAbs_FACE));

    view_->FitAll();
    view_->ZFitAll();
    view_->Redraw();
}

void Viewer::refreshMainPresentation()
{
    if (presentation_.IsNull()) {
        presentation_ = new AIS_Shape(currentShape_);
        presentation_->SetColor(Quantity_NOC_LIGHTSTEELBLUE);
        presentation_->Attributes()->SetFaceBoundaryDraw(Standard_True);
        context_->Display(
            presentation_,
            isShaded_ ? AIS_Shaded : AIS_WireFrame,
            0,
            Standard_True);
    } else {
        presentation_->SetShape(currentShape_);
        context_->Redisplay(presentation_, Standard_True);
        context_->SetDisplayMode(
            presentation_,
            isShaded_ ? AIS_Shaded : AIS_WireFrame,
            Standard_True);
    }

    context_->Activate(presentation_, AIS_Shape::SelectionMode(TopAbs_FACE));
    view_->FitAll();
    view_->ZFitAll();
    view_->Redraw();
}

void Viewer::toggleDisplayMode()
{
    if (context_.IsNull() || view_.IsNull() || presentation_.IsNull()) {
        return;
    }

    isShaded_ = !isShaded_;
    context_->SetDisplayMode(
        presentation_,
        isShaded_ ? AIS_Shaded : AIS_WireFrame,
        Standard_True);
    view_->Redraw();
}

void Viewer::setAxisView(char axis, bool positive)
{
    if (view_.IsNull()) {
        return;
    }

    V3d_TypeOfOrientation orientation;
    switch (axis) {
    case 'x':
    case 'X':
        orientation = positive ? V3d_Xpos : V3d_Xneg;
        break;
    case 'y':
    case 'Y':
        orientation = positive ? V3d_Ypos : V3d_Yneg;
        break;
    case 'z':
    case 'Z':
        orientation = positive ? V3d_Zpos : V3d_Zneg;
        break;
    default:
        return;
    }

    view_->SetProj(orientation);
    view_->FitAll();
    view_->ZFitAll();
    view_->Redraw();
}

bool Viewer::updateSelectedFaceFromContext()
{
    selectedFace_.Nullify();
    selectedSketchProfile_ = false;

    if (context_.IsNull() || context_->NbSelected() == 0) {
        return false;
    }

    const Handle(AIS_InteractiveObject) selectedObject =
        context_->SelectedInteractive();

    if (!sketchPresentation_.IsNull()
        && selectedObject == sketchPresentation_) {
        selectedSketchProfile_ = !sketchFace_.IsNull();
        return selectedSketchProfile_;
    }

    const TopoDS_Shape selectedShape = context_->SelectedShape();
    if (selectedShape.IsNull() || selectedShape.ShapeType() != TopAbs_FACE) {
        return false;
    }

    selectedFace_ = TopoDS::Face(selectedShape);
    return true;
}

bool Viewer::beginSketchOnSelectedFace()
{
    if (selectedFace_.IsNull()) {
        if (!updateSelectedFaceFromContext() || selectedFace_.IsNull()) {
            return false;
        }
    }

    BRepAdaptor_Surface surface(selectedFace_, Standard_True);
    if (surface.GetType() != GeomAbs_Plane) {
        return false;
    }

    sketchAxes_ = surface.Plane().Position();
    if (selectedFace_.Orientation() == TopAbs_REVERSED) {
        sketchAxes_.ZReverse();
    }

    clearSketchProfile();
    sketchFirstPoint_.reset();
    sketchMode_ = true;

    // Keep the model visible but make sketch input unambiguous.
    context_->ClearSelected(Standard_True);
    view_->Redraw();
    return true;
}

void Viewer::exitSketchMode()
{
    sketchMode_ = false;
    sketchFirstPoint_.reset();
    view_->Redraw();
}

bool Viewer::screenPointOnSketchPlane(const QPoint& point, gp_Pnt& result) const
{
    if (!sketchMode_ || view_.IsNull()) {
        return false;
    }

    Standard_Real x = 0.0;
    Standard_Real y = 0.0;
    Standard_Real z = 0.0;
    Standard_Real vx = 0.0;
    Standard_Real vy = 0.0;
    Standard_Real vz = 0.0;

    view_->ConvertWithProj(
        point.x(), point.y(),
        x, y, z,
        vx, vy, vz);

    const gp_Pnt rayOrigin(x, y, z);
    gp_Vec rayDirection(vx, vy, vz);
    if (rayDirection.SquareMagnitude() < 1.0e-18) {
        return false;
    }
    rayDirection.Normalize();

    const gp_Pnt planeOrigin = sketchAxes_.Location();
    const gp_Vec planeNormal(sketchAxes_.Direction());
    const double denominator = rayDirection.Dot(planeNormal);
    if (std::abs(denominator) < 1.0e-9) {
        return false;
    }

    const gp_Vec originToPlane(rayOrigin, planeOrigin);
    const double t = originToPlane.Dot(planeNormal) / denominator;
    result = rayOrigin.Translated(rayDirection * t);
    return true;
}

bool Viewer::createRectangleSketch(const gp_Pnt& first, const gp_Pnt& second)
{
    const gp_Pnt origin = sketchAxes_.Location();
    const gp_Vec xAxis(sketchAxes_.XDirection());
    const gp_Vec yAxis(sketchAxes_.YDirection());

    const gp_Vec toFirst(origin, first);
    const gp_Vec toSecond(origin, second);

    const double u1 = toFirst.Dot(xAxis);
    const double v1 = toFirst.Dot(yAxis);
    const double u2 = toSecond.Dot(xAxis);
    const double v2 = toSecond.Dot(yAxis);

    if (std::abs(u2 - u1) < 1.0e-6 || std::abs(v2 - v1) < 1.0e-6) {
        return false;
    }

    auto pointAt = [&](double u, double v) {
        return origin.Translated(xAxis * u + yAxis * v);
    };

    const gp_Pnt p1 = pointAt(u1, v1);
    const gp_Pnt p2 = pointAt(u2, v1);
    const gp_Pnt p3 = pointAt(u2, v2);
    const gp_Pnt p4 = pointAt(u1, v2);

    BRepBuilderAPI_MakePolygon polygon;
    polygon.Add(p1);
    polygon.Add(p2);
    polygon.Add(p3);
    polygon.Add(p4);
    polygon.Close();

    if (!polygon.IsDone()) {
        return false;
    }

    const TopoDS_Wire wire = polygon.Wire();
    BRepBuilderAPI_MakeFace faceMaker(wire, Standard_True);
    if (!faceMaker.IsDone()) {
        return false;
    }

    clearSketchProfile();
    sketchFace_ = faceMaker.Face();

    sketchPresentation_ = new AIS_Shape(sketchFace_);
    sketchPresentation_->SetColor(Quantity_NOC_ORANGE);
    sketchPresentation_->SetTransparency(0.55);
    sketchPresentation_->Attributes()->SetFaceBoundaryDraw(Standard_True);

    context_->Display(sketchPresentation_, AIS_Shaded, 0, Standard_True);
    context_->Activate(
        sketchPresentation_,
        AIS_Shape::SelectionMode(TopAbs_FACE));

    selectedSketchProfile_ = true;
    view_->Redraw();
    return true;
}

void Viewer::clearSketchProfile()
{
    if (!sketchPresentation_.IsNull() && !context_.IsNull()) {
        context_->Remove(sketchPresentation_, Standard_True);
    }
    sketchPresentation_.Nullify();
    sketchFace_.Nullify();
    selectedSketchProfile_ = false;
}

bool Viewer::canExtrudeSelection() const
{
    return selectedSketchProfile_ || !selectedFace_.IsNull();
}

bool Viewer::extrudeSelected(double distanceMm)
{
    if (std::abs(distanceMm) < 1.0e-9 || currentShape_.IsNull()) {
        return false;
    }

    TopoDS_Face sourceFace;
    gp_Dir normal;

    if (selectedSketchProfile_ && !sketchFace_.IsNull()) {
        sourceFace = sketchFace_;
        normal = sketchAxes_.Direction();
    } else if (!selectedFace_.IsNull()) {
        sourceFace = selectedFace_;
        try {
            normal = outwardNormal(selectedFace_);
        } catch (const std::exception&) {
            return false;
        }
    } else {
        return false;
    }

    const bool isCut = distanceMm < 0.0;
    gp_Vec vector(normal);
    vector *= distanceMm;

    BRepPrimAPI_MakePrism prismMaker(sourceFace, vector, Standard_True);
    if (!prismMaker.IsDone()) {
        return false;
    }

    const TopoDS_Shape prism = prismMaker.Shape();
    TopoDS_Shape result;

    if (isCut) {
        BRepAlgoAPI_Cut cut(currentShape_, prism);
        cut.Build();
        if (!cut.IsDone()) {
            return false;
        }
        result = cut.Shape();
    } else {
        BRepAlgoAPI_Fuse fuse(currentShape_, prism);
        fuse.Build();
        if (!fuse.IsDone()) {
            return false;
        }
        result = fuse.Shape();
    }

    if (result.IsNull()) {
        return false;
    }

    currentShape_ = result;
    selectedFace_.Nullify();
    context_->ClearSelected(Standard_False);

    if (selectedSketchProfile_) {
        clearSketchProfile();
    }

    sketchMode_ = false;
    sketchFirstPoint_.reset();
    refreshMainPresentation();
    return true;
}

bool Viewer::exportStep(const std::string& path) const
{
    if (currentShape_.IsNull()) {
        return false;
    }

    STEPControl_Writer writer;
    if (writer.Transfer(currentShape_, STEPControl_AsIs) != IFSelect_RetDone) {
        return false;
    }

    return writer.Write(path.c_str()) == IFSelect_RetDone;
}

bool Viewer::exportStl(const std::string& path) const
{
    if (currentShape_.IsNull()) {
        return false;
    }

    BRepMesh_IncrementalMesh mesh(currentShape_, 0.1, Standard_False, 0.5, Standard_True);
    mesh.Perform();
    if (!mesh.IsDone()) {
        return false;
    }

    StlAPI_Writer writer;
    writer.ASCIIMode() = Standard_False;
    return writer.Write(currentShape_, path.c_str());
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

    if (event->button() != Qt::LeftButton || context_.IsNull()) {
        return;
    }

    if (sketchMode_) {
        gp_Pnt point;
        if (!screenPointOnSketchPlane(lastMousePosition_, point)) {
            return;
        }

        if (!sketchFirstPoint_.has_value()) {
            sketchFirstPoint_ = point;
        } else {
            createRectangleSketch(*sketchFirstPoint_, point);
            sketchFirstPoint_.reset();
        }
        return;
    }

    context_->MoveTo(
        lastMousePosition_.x(),
        lastMousePosition_.y(),
        view_,
        Standard_True);
    context_->SelectDetected();
    updateSelectedFaceFromContext();
}

void Viewer::mouseMoveEvent(QMouseEvent* event)
{
    const QPoint position = event->position().toPoint();

    if (sketchMode_) {
        lastMousePosition_ = position;
        return;
    }

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
