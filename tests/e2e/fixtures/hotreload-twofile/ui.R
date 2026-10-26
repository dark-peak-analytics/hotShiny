library(hotShiny)

fluidPage(
  h2(id = "title", "Version one"),
  textInput("name", "Name", value = "initial"),
  textOutput("greeting"),
  counterUI("counter")
)
