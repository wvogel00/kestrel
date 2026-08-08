#pragma once

#include <QPoint>
#include <QWidget>

#include <AIS_InteractiveContext.hxx>
#include <V3d_View.hxx>
#include <V3d_Viewer.hxx>

#include <kestrel/model/ModelSpec.hpp>

namespace kestrel::occt {

class Viewer final : public QWidget {
public:
    explicit Viewer(const kestrel::model::BoxSpec& boxSpec,
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
    void displayBox(const kestrel::model::BoxSpec& boxSpec);

    Handle(V3d_Viewer) viewer_;
    Handle(V3d_View) view_;
    Handle(AIS_InteractiveContext) context_;

    QPoint lastMousePosition_;
};

} // namespace kestrel::occt
