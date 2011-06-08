#!/usr/bin/perl
# vi: set ts=4 sw=4 :

use warnings;
use strict;

package BlobServer::Upload;

use Apache2::Const qw(
	HTTP_METHOD_NOT_ALLOWED
	HTTP_CREATED
	OK
	HTTP_INTERNAL_SERVER_ERROR
);
use Apache2::RequestRec;
use Apache2::Response;
use Apache2::RequestIO;
use APR::Table;

use File::Temp 'tempfile';
use Digest::SHA1;

sub handler {
	my ($r) = @_;

	return HTTP_METHOD_NOT_ALLOWED
		unless $r->method eq "POST";

	# TODO reject if multipart or form-data
	# (just to stop the common errors)

	my ($checksum, $status) = store($r);
	return $status if $status;

	$r->status(HTTP_CREATED);
	$r->headers_out->set("Location", "http://127.0.0.1:8080/blob/$checksum");
	$r->content_type("text/plain");
	$r->print("$checksum\n");

	return OK;
}

sub store {
	my ($r) = @_;

	my $tmp_dir = $r->subprocess_env("TMP_DIR");
	my $blob_dir = $r->subprocess_env("BLOB_DIR");

	my ($fh, $name) = tempfile(
		"upload-XXXXXXXX",
		DIR => $tmp_dir,
	) or goto FAIL;

	my $sha1 = Digest::SHA1->new;

	my $size = 16384;
	while (my $len = $r->read(my $buffer, $size)) {
		$sha1->add($buffer);
		print $fh $buffer or goto FAIL;
	}

	close $fh or goto FAIL;

	my $checksum = $sha1->hexdigest;

	chmod 0644, $name or goto FAIL;

	rename $name, "$blob_dir/$checksum" or goto FAIL;

	return($checksum);

	FAIL:

	my $err = $!;
	unlink $name if defined $name;
	print STDERR "Error: $err\n";
	$r->content_type("text/plain");
	$r->print("Error: $err\n");
	return (undef, HTTP_INTERNAL_SERVER_ERROR);
}

1;