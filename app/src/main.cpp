#include "MainWindow.hpp"

#include <QApplication>

int main(int argc, char* argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName("Kestrel");
    QApplication::setOrganizationName("Kestrel");

    MainWindow window;
    window.show();

    return app.exec();
}
