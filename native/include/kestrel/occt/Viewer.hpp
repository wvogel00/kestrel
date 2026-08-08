#pragma once

#include <QPoint>
#include <QWidget>

#include <AIS_InteractiveContext.hxx>
#include <TopoDS_Shape.hxx>
#include <V3d_View.hxx>
#include <V3d_Viewer.hxx>

#include <kestrel/model/ModelSpec.hpp>

namespace kestrel::occt {

class Viewer final : public QWidget {
public:
    explicit Viewer(const kestrel::model::NodeSpec& model,
                    QWidget* parent = nullptr);
    ~Viewer() override = default;

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
    TopoDS_Shape evaluate(const kestrel::model::NodeSpec& node) const;

    Handle(V3d_Viewer) viewer_;
    Handle(V3d_View) view_;
    Handle(AIS_InteractiveContext) context_;

    QPoint lastMousePosition_;
};

} // namespace kestrel::occt
