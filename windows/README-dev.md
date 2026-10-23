# BlackBreak for Windows: development

Install the .NET 10 SDK locally (no admin needed):

    curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    bash /tmp/dotnet-install.sh --channel 10.0 --install-dir ~/.dotnet
    ~/.dotnet/dotnet --version   # 10.*

Run the tests (the shared `../spec/*.json` cases are linked into the test output):

    ~/.dotnet/dotnet test windows/Core.Tests
