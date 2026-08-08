#include <kestrel/occt/Viewer.hpp>

namespace kestrel::occt {

void Viewer::pushUndoState()
{
    if (!currentShape_.IsNull()) {
        undoStack_.push_back(currentShape_);
    }
}

bool Viewer::undoLastEdit()
{
    if (undoStack_.empty()) {
        return false;
    }

    currentShape_ = undoStack_.back();
    undoStack_.pop_back();

    selectedFace_.Nullify();
    if (!context_.IsNull()) {
        context_->ClearSelected(Standard_False);
    }

    if (!sketchPresentation_.IsNull()) {
        clearSketchProfile();
    }

    sketchMode_ = false;
    sketchFirstPoint_.reset();

    refreshMainPresentation();
    return true;
}

} // namespace kestrel::occt
