package app

#AppWithTransform: #App & {
    output:
        hello:
            name: "chaz"
}

input: #AppWithTransform
output: input & #AppWithTransform