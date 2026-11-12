# Using oui

## Choose a boundary {#choose-a-boundary}

Start with the interface your application needs. Headless layout can be selected separately; interaction, text, component families and the SDL3 backend are opt-in. Select the packages and their dependencies according to the actual integration rather than assuming the whole repository is required.

## Ownership and resources {#ownership-and-resources}

The consumer owns the application model and meaningful values. Follow the library's lifecycle and error contracts when preparing, using and recovering resources. Fonts, Unicode data and native codecs have their own dependencies and notices; the kit's MIT license does not relicense them.

The [quickstart](https://github.com/atilla777/oui/blob/main/docs/quickstart.md), [recipes](https://github.com/atilla777/oui/blob/main/docs/recipes.md) and [resource guide](https://github.com/atilla777/oui/blob/main/docs/resources.md) are the authoritative starting points for commands and prerequisites. Native consumers do not need this website's Node tooling.
