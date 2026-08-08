#include <kestrel/occt/Viewer.hpp>

#include <cmath>

#include <AIS_Shape.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRep_Tool.hxx>
#include <Prs3d_Drawer.hxx>
#include <Prs3d_TypeOfHighlight.hxx>
#include <Quantity_NameOfColor.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Vertex.hxx>
#include <TopoDS_Wire.hxx>
#include <gp_Vec.hxx>

namespace kestrel::occt {
namespace {

void localUv(const gp_Ax3& axes, const gp_Pnt& point, double& u, double& v)
{
    const gp_Vec fromOrigin(axes.Location(), point);
    u = fromOrigin.Dot(gp_Vec(axes.XDirection()));
    v = fromOrigin.Dot(gp_Vec(axes.YDirection()));
}

bool pointLiesOnSketchPlane(const gp_Ax3& axes,
                            const gp_Pnt& point,
                            double tolerance = 1.0e-6)
{
    const gp_Vec fromPlaneOrigin(axes.Location(), point);
    const gp_Vec normal(axes.Direction());
    return std::abs(fromPlaneOrigin.Dot(normal)) <= tolerance;
}

} // namespace

void Viewer::enableSketchInteraction()
{
    if (!sketchMode_ || context_.IsNull() || presentation_.IsNull()) {
        return;
    }

    hasSketchRectangle_ = false;
    sketchU1_ = sketchV1_ = sketchU2_ = sketchV2_ = 0.0;
    sketchFirstPoint_.reset();

    // During sketch placement, model vertices are selectable as optional snap
    // targets. Clicking anywhere else on the face remains valid and creates a
    // free point by projecting the cursor onto the sketch plane.
    context_->ClearSelected(Standard_False);
    context_->Deactivate(presentation_);
    context_->Activate(presentation_, AIS_Shape::SelectionMode(TopAbs_VERTEX));

    const Handle(Prs3d_Drawer)& dynamicStyle =
        context_->HighlightStyle(Prs3d_TypeOfHighlight_LocalDynamic);
    if (!dynamicStyle.IsNull()) {
        dynamicStyle->SetColor(Quantity_NOC_YELLOW);
    }

    view_->Redraw();
}

void Viewer::disableSketchInteraction()
{
    if (context_.IsNull()) {
        return;
    }

    context_->ClearSelected(Standard_False);

    if (!presentation_.IsNull()) {
        context_->Deactivate(presentation_);
        context_->Activate(presentation_, AIS_Shape::SelectionMode(TopAbs_FACE));
    }

    // Once sketch editing is finished, the profile is selected as a face for
    // extrusion rather than as individual edges for dimensional constraints.
    if (!sketchPresentation_.IsNull()) {
        context_->Deactivate(sketchPresentation_);
        context_->Activate(
            sketchPresentation_,
            AIS_Shape::SelectionMode(TopAbs_FACE));
    }

    selectedSketchProfile_ = false;
    view_->Redraw();
}

bool Viewer::snappedSketchPoint(const QPoint& point, gp_Pnt& result)
{
    if (context_.IsNull() || view_.IsNull() || !sketchMode_) {
        return false;
    }

    // Refresh OCCT detection for this exact click position. DetectedShape()
    // must not be queried unless HasDetected() is true; otherwise stale/empty
    // detection state can be observed after moving away from a vertex.
    context_->MoveTo(point.x(), point.y(), view_, Standard_False);

    if (context_->HasDetected()) {
        const TopoDS_Shape detected = context_->DetectedShape();
        if (!detected.IsNull() && detected.ShapeType() == TopAbs_VERTEX) {
            const gp_Pnt vertexPoint = BRep_Tool::Pnt(TopoDS::Vertex(detected));

            // Only snap to vertices that actually belong to the current sketch
            // plane. A visible/hidden vertex on another parallel face should
            // not pull a 2-D sketch point out of plane.
            if (pointLiesOnSketchPlane(sketchAxes_, vertexPoint)) {
                result = vertexPoint;
                return true;
            }
        }
    }

    // No valid vertex snap target: the click is still valid. Project the
    // cursor ray onto the sketch plane and use that as an unconstrained point.
    return screenPointOnSketchPlane(point, result);
}

bool Viewer::handleSketchMouseMove(const QPoint& point)
{
    if (!sketchMode_ || context_.IsNull() || view_.IsNull()) {
        return false;
    }

    // Before a rectangle exists this highlights body vertices. Afterwards it
    // highlights sketch edges, making the D-dimension workflow explicit.
    context_->MoveTo(point.x(), point.y(), view_, Standard_True);
    return true;
}

bool Viewer::handleSketchMousePress(const QPoint& point)
{
    if (!sketchMode_ || context_.IsNull() || view_.IsNull()) {
        return false;
    }

    if (hasSketchRectangle_ && !sketchPresentation_.IsNull()) {
        context_->MoveTo(point.x(), point.y(), view_, Standard_True);
        if (context_->HasDetected()) {
            context_->SelectDetected();
        }
        return true;
    }

    gp_Pnt sketchPoint;
    if (!snappedSketchPoint(point, sketchPoint)) {
        return true;
    }

    if (!sketchFirstPoint_.has_value()) {
        sketchFirstPoint_ = sketchPoint;
        return true;
    }

    const gp_Pnt first = *sketchFirstPoint_;
    if (!createRectangleSketch(first, sketchPoint)) {
        return true;
    }

    localUv(sketchAxes_, first, sketchU1_, sketchV1_);
    localUv(sketchAxes_, sketchPoint, sketchU2_, sketchV2_);
    hasSketchRectangle_ = true;
    sketchFirstPoint_.reset();

    activateSketchEdgeSelection();
    return true;
}

void Viewer::activateSketchEdgeSelection()
{
    if (context_.IsNull() || sketchPresentation_.IsNull()) {
        return;
    }

    context_->ClearSelected(Standard_False);
    context_->Deactivate(sketchPresentation_);
    context_->Activate(
        sketchPresentation_,
        AIS_Shape::SelectionMode(TopAbs_EDGE));

    // Stop body vertices competing with sketch-edge selection once the
    // rectangle has been created.
    if (!presentation_.IsNull()) {
        context_->Deactivate(presentation_);
    }

    selectedSketchProfile_ = false;
    view_->Redraw();
}

bool Viewer::selectedSketchEdgeInfo(bool& horizontal, double& lengthMm)
{
    horizontal = false;
    lengthMm = 0.0;

    if (!hasSketchRectangle_ || context_.IsNull()
        || sketchPresentation_.IsNull() || context_->NbSelected() == 0) {
        return false;
    }

    context_->InitSelected();
    if (!context_->MoreSelected()
        || context_->SelectedInteractive() != sketchPresentation_) {
        return false;
    }

    const TopoDS_Shape selected = context_->SelectedShape();
    if (selected.IsNull() || selected.ShapeType() != TopAbs_EDGE) {
        return false;
    }

    TopoDS_Vertex firstVertex;
    TopoDS_Vertex lastVertex;
    TopExp::Vertices(TopoDS::Edge(selected), firstVertex, lastVertex);
    if (firstVertex.IsNull() || lastVertex.IsNull()) {
        return false;
    }

    const gp_Pnt p1 = BRep_Tool::Pnt(firstVertex);
    const gp_Pnt p2 = BRep_Tool::Pnt(lastVertex);

    double u1 = 0.0;
    double v1 = 0.0;
    double u2 = 0.0;
    double v2 = 0.0;
    localUv(sketchAxes_, p1, u1, v1);
    localUv(sketchAxes_, p2, u2, v2);

    const double du = std::abs(u2 - u1);
    const double dv = std::abs(v2 - v1);
    horizontal = du >= dv;
    lengthMm = horizontal ? du : dv;
    return lengthMm > 1.0e-9;
}

double Viewer::selectedSketchEdgeLength()
{
    bool horizontal = false;
    double lengthMm = 0.0;
    return selectedSketchEdgeInfo(horizontal, lengthMm) ? lengthMm : -1.0;
}

bool Viewer::setSelectedSketchDimension(double lengthMm)
{
    if (lengthMm <= 1.0e-9 || !hasSketchRectangle_) {
        return false;
    }

    bool horizontal = false;
    double currentLength = 0.0;
    if (!selectedSketchEdgeInfo(horizontal, currentLength)) {
        return false;
    }

    if (horizontal) {
        const double sign = sketchU2_ >= sketchU1_ ? 1.0 : -1.0;
        sketchU2_ = sketchU1_ + sign * lengthMm;
    } else {
        const double sign = sketchV2_ >= sketchV1_ ? 1.0 : -1.0;
        sketchV2_ = sketchV1_ + sign * lengthMm;
    }

    return rebuildSketchRectangle();
}

bool Viewer::rebuildSketchRectangle()
{
    if (!hasSketchRectangle_ || context_.IsNull()) {
        return false;
    }

    const gp_Pnt origin = sketchAxes_.Location();
    const gp_Vec xAxis(sketchAxes_.XDirection());
    const gp_Vec yAxis(sketchAxes_.YDirection());

    auto pointAt = [&](double u, double v) {
        return origin.Translated(xAxis * u + yAxis * v);
    };

    const gp_Pnt p1 = pointAt(sketchU1_, sketchV1_);
    const gp_Pnt p2 = pointAt(sketchU2_, sketchV1_);
    const gp_Pnt p3 = pointAt(sketchU2_, sketchV2_);
    const gp_Pnt p4 = pointAt(sketchU1_, sketchV2_);

    BRepBuilderAPI_MakePolygon polygon;
    polygon.Add(p1);
    polygon.Add(p2);
    polygon.Add(p3);
    polygon.Add(p4);
    polygon.Close();
    if (!polygon.IsDone()) {
        return false;
    }

    BRepBuilderAPI_MakeFace faceMaker(polygon.Wire(), Standard_True);
    if (!faceMaker.IsDone()) {
        return false;
    }

    if (!sketchPresentation_.IsNull()) {
        context_->Remove(sketchPresentation_, Standard_False);
    }

    sketchFace_ = faceMaker.Face();
    sketchPresentation_ = new AIS_Shape(sketchFace_);
    sketchPresentation_->SetColor(Quantity_NOC_ORANGE);
    sketchPresentation_->SetTransparency(0.55);
    sketchPresentation_->Attributes()->SetFaceBoundaryDraw(Standard_True);
    context_->Display(sketchPresentation_, AIS_Shaded, 0, Standard_False);

    activateSketchEdgeSelection();
    context_->UpdateCurrentViewer();
    return true;
}

} // namespace kestrel::occt
