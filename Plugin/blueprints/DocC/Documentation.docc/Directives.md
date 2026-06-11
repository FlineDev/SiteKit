# DocC Directives

A live showcase of the layout, video, and tab directives SiteKit renders. Each one matches Swift-DocC, including the interactive parts.

@Metadata {
   @TitleHeading("Guide")
   @PageKind(article)
}

> **Quick Read**:
> _`@Row`/`@Column` honour their `size` weights, `@Video` plays inline, and `@TabNavigator` switches tabs with no JavaScript._

## Rows and columns

A `@Row` lays its `@Column` children out side by side. A column's `size:` weight controls how much space it claims, so a `size: 2` text column sits next to a `size: 1` image at a 2:1 ratio (exactly like Swift-DocC). On a narrow screen the columns stack.

@Row(numberOfColumns: 3) {
   @Column(size: 2) {
      ### Wide text column

      This column carries a `size` of 2, so it takes roughly two thirds of the row. The narrower image column beside it carries a `size` of 1 and takes the remaining third. The ratio is driven entirely by the `size` weights, not a fixed 50/50 split.
   }
   @Column(size: 1) {
      @Image(source: "Directives-Layout", alt: "A placeholder tile illustrating the 2 to 1 column split")
   }
}

## Video

`@Video` renders an inline player that autoplays, loops, and stays muted, just like the short demo clips in Apple's own documentation. A `poster:` image shows before the clip starts.

@Video(source: "Directives-Demo.mp4", poster: "Directives-Poster")

## Tabs

`@TabNavigator` turns its `@Tab` children into an interactive tab bar. Only the selected tab's content is shown, and clicking another tab switches it, with no JavaScript involved.

@TabNavigator {
   @Tab("Declared") {
      @Image(source: "Directives-Tab-Declared", alt: "Placeholder tile for the Declared tab")
   }
   @Tab("Resolved") {
      @Image(source: "Directives-Tab-Resolved", alt: "Placeholder tile for the Resolved tab")
   }
}

A second tab group on the same page switches independently of the first.

@TabNavigator {
   @Tab("Light") {
      @Image(source: "Directives-Tab-Light", alt: "Placeholder tile for the Light tab")
   }
   @Tab("Dark") {
      @Image(source: "Directives-Tab-Dark", alt: "Placeholder tile for the Dark tab")
   }
}
