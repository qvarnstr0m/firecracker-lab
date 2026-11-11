// Package firecracker is a minimal client for the Firecracker REST API over a
// Unix socket. It covers only what the lab needs; lab 08 grows it step by step.
package firecracker

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
)

// Client talks to one Firecracker process through its API socket.
type Client struct {
	http *http.Client
}

// New returns a client for the API socket at socketPath.
func New(socketPath string) *Client {
	return &Client{http: &http.Client{
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
				var d net.Dialer
				return d.DialContext(ctx, "unix", socketPath)
			},
		},
	}}
}

// Put sends a PUT request with body encoded as JSON, the same call as
// curl --unix-socket <sock> -X PUT http://localhost<path> -d '<json>'.
func (c *Client) Put(ctx context.Context, path string, body any) error {
	return c.do(ctx, http.MethodPut, path, body)
}

// Patch sends a PATCH request, used for example to pause and resume a VM.
func (c *Client) Patch(ctx context.Context, path string, body any) error {
	return c.do(ctx, http.MethodPatch, path, body)
}

func (c *Client) do(ctx context.Context, method, path string, body any) error {
	buf, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, method, "http://localhost"+path, bytes.NewReader(buf))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		msg, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("%s %s: %s: %s", method, path, resp.Status, bytes.TrimSpace(msg))
	}
	return nil
}
