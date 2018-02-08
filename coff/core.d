module coff.core;

template CoffLinker(Policy)
{
    struct Linker
    {
        SymbolTable symbolTable;
        Driver driver;

        void link()
        {
            driver.link();
        }
    }
}