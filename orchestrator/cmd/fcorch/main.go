// Command fcorch is the mini orchestrator built in lab 08.
//
// It starts as a placeholder; the lab adds an HTTP API that creates and
// destroys microVMs from container images, roughly like fly.io's flyd.
package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	addr := flag.String("listen", "127.0.0.1:8090", "address for the HTTP API")
	flag.Parse()

	fmt.Fprintf(os.Stderr, "fcorch: not implemented yet (would listen on %s). See labs/08-mini-orchestrator.md\n", *addr)
	os.Exit(1)
}
