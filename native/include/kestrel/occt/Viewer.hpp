#pragma once

#include <optional>
#include <string>
#include <vector>

#include <QPoint>
#include <QWidget>

#include <AIS_InteractiveContext.hxx>
#include <AIS_Shape.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <V3d_View.hxx>
#include <V3d_Viewer.hxx>
#include <gp_Ax3.hxx>
#include <gp_Pnt.hxx>

#include <kestrel/model/ModelSpec.hpp>

namespace kestrel::occt {

class Viewer final : public QWidget {
public:
    explicit Viewer(const kestrel::model::NodeSpec& model,
                    QWidget* parent = nullptr);
    ~Viewer() override = default;

    void toggleDisplayMode();
    void setAxisView(char axis, bool positive);

    bool beginSketchOnSelectedFace();
    void exitSketchMode();
    bool isSketchMode() const { return sketchMode_; }

    bool canExtrudeSelection();
    bool extrudeSelected(double distanceMm);

    void pushUndoState();
    bool undoLastEdit();

    bool exportStep(const std::string& path) const;
    bool exportStl(const std::string& path) const;

protected:
    QPaintEngine* paintEngine() const override;
    void paintEvent(QPaintEvent* event) override;
    void resizeEvent(QResizeEvent* event) override;
    void mousePressEvent(QMouseEvent* event) override;
    void mouseMoveEvent(QMouseEvent* event) override;
    void wheelEvent(QWheelEvent* event) override;

private:
    void initializeOcct();
    void displayModel(const kestrel::model::NodeSpec& model);
    void refreshMainPresentation();
    TopoDS_Shape evaluate(const kestrel::model::NodeSpec& node) const;

    bool updateSelectedFaceFromContext();
    bool screenPointOnSketchPlane(const QPoint& point, gp_Pnt& result) const;
    bool createRectangleSketch(const gp_Pnt& first, const gp_Pnt& second);
    void clearSketchProfile();

    Handle(V3d_Viewer) viewer_;
    Handle(V3d_View) view_;
    Handle(AIS_InteractiveContext) context_;
    Handle(AIS_Shape) presentation_;
    Handle(AIS_Shape) sketchPresentation_;

    TopoDS_Shape currentShape_;
    TopoDS_Face selectedFace_;
    TopoDS_Face sketchFace_;
    std::vector<TopoDS_Shape> undoStack_;

    QPoint lastMousePosition_;
    bool isShaded_ = true;

    bool sketchMode_ = false;
    bool selectedSketchProfile_ = false;
    gp_Ax3 sketchAxes_;
    std::optional<gp_Pnt> sketchFirstPoint_;
};

} // namespace kestrel::occt
